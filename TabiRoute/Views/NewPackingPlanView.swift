import SwiftUI
import SwiftData
import CoreLocation

/// Creating a plan starts from an existing `Trip` instead of a blank form —
/// destination, dates and coordinate are all derived from that trip's photo
/// locations/dates. The only thing left for the user to pick is trip type.
struct NewPackingPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    @State private var selectedTrip: Trip?
    @State private var tripType: TripType = .sightseeing
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var derivedDestination: String?
    @State private var derivedIsoCountryCode: String?
    @State private var derivedStartDate: Date?
    @State private var derivedEndDate: Date?
    @State private var derivedCoordinate: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedTrip {
                    confirmView(for: selectedTrip)
                } else {
                    tripPickerView
                }
            }
            .navigationTitle("持ち物リストを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var tripPickerView: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView(
                    "旅ルートがありません",
                    systemImage: "map",
                    description: Text("先に「旅ルート」タブで写真からトリップを作成してください")
                )
            } else {
                List(trips) { trip in
                    Button {
                        Task { await selectTrip(trip) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(trip.name).font(.headline)
                            Text(trip.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func confirmView(for trip: Trip) -> some View {
        Form {
            Section("トリップ") {
                Text(trip.name)
                if let derivedDestination {
                    LabeledContent("目的地", value: derivedDestination)
                }
                if let derivedStartDate, let derivedEndDate {
                    LabeledContent("日程", value: "\(derivedStartDate.formatted(date: .abbreviated, time: .omitted)) 〜 \(derivedEndDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }

            if isLoading {
                ProgressView("トリップから読み込み中...")
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Section("旅行タイプ") {
                    Picker("タイプ", selection: $tripType) {
                        ForEach(TripType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Button("この内容で作成") {
                    save(trip: trip)
                }
            }
        }
    }

    private func selectTrip(_ trip: Trip) async {
        isLoading = true
        errorMessage = nil
        selectedTrip = trip

        let data = PhotoLibraryService.loadTripPhotoData(assetIdentifiers: trip.assetIdentifiers)
        guard !data.geoPoints.isEmpty else {
            errorMessage = "この旅ルートには位置情報のある写真がありませんでした"
            isLoading = false
            return
        }

        let lats = data.geoPoints.map(\.coordinate.latitude)
        let lons = data.geoPoints.map(\.coordinate.longitude)
        let coordinate = CLLocationCoordinate2D(
            latitude: lats.reduce(0, +) / Double(lats.count),
            longitude: lons.reduce(0, +) / Double(lons.count)
        )

        derivedCoordinate = coordinate
        derivedStartDate = data.geoPoints.map(\.date).min()
        derivedEndDate = data.geoPoints.map(\.date).max()
        let details = await PlacemarkService.details(for: coordinate)
        derivedDestination = details.name ?? trip.name
        derivedIsoCountryCode = details.isoCountryCode

        isLoading = false
    }

    private func save(trip: Trip) {
        guard let coordinate = derivedCoordinate,
              let startDate = derivedStartDate,
              let endDate = derivedEndDate else { return }

        let plan = PackingPlan(
            sourceTripID: trip.id,
            destinationName: derivedDestination ?? trip.name,
            destinationIsoCountryCode: derivedIsoCountryCode,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            startDate: startDate,
            endDate: endDate,
            tripType: tripType
        )
        modelContext.insert(plan)
        dismiss()
    }
}
