import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var isShowingPicker = false

    var body: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripMapView(trip: trip)
                } label: {
                    VStack(alignment: .leading) {
                        Text(trip.name).font(.headline)
                        Text(trip.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteTrips)
        }
        .overlay {
            if trips.isEmpty {
                ContentUnavailableView(
                    "まだトリップがありません",
                    systemImage: "map",
                    description: Text("右上の＋から写真を選んでルート地図を作成しましょう")
                )
            }
        }
        .navigationTitle("マイトリップ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingPicker = true
                } label: {
                    Label("新規トリップ", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            PhotoPickerSheet { identifiers in
                guard !identifiers.isEmpty else { return }
                let trip = Trip(name: defaultTripName(), assetIdentifiers: identifiers)
                modelContext.insert(trip)
            }
        }
    }

    private func defaultTripName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日の旅"
        return formatter.string(from: .now)
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }
}
