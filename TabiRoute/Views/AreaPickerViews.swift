import SwiftUI
import MapKit

/// The 県 → 市/町 → 観光地 drill-down alternative to typing a search —
/// pushed within whichever `NavigationStack` hosts it (the caller's
/// sheet), so `dismiss()` from the deepest screen closes the whole thing.
struct PrefectureListView: View {
    var onSelect: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
        List(TohokuArea.prefectures) { prefecture in
            NavigationLink(prefecture.name) {
                CityListView(prefecture: prefecture, onSelect: onSelect)
            }
        }
    }
}

struct CityListView: View {
    let prefecture: TohokuPrefecture
    var onSelect: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
        List(prefecture.cities, id: \.self) { city in
            NavigationLink(city) {
                SpotListView(areaName: city, onSelect: onSelect)
            }
        }
        .navigationTitle(prefecture.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SpotListView: View {
    let areaName: String
    var onSelect: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var areaCoordinate: CLLocationCoordinate2D?
    @State private var spots: [Spot] = []
    @State private var isLoading = true

    private struct Spot: Identifiable {
        let id = UUID()
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        List {
            if let areaCoordinate {
                Section {
                    Button("\(areaName)を選択") {
                        onSelect(areaName, areaCoordinate)
                        dismiss()
                    }
                }
            }
            if !spots.isEmpty {
                Section("観光地") {
                    ForEach(spots) { spot in
                        Button(spot.name) {
                            onSelect(spot.name, spot.coordinate)
                            dismiss()
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(areaName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let coordinate = await ClimateService.geocode(destinationName: areaName) else {
            isLoading = false
            return
        }
        areaCoordinate = coordinate

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "観光地"
        request.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
        request.resultTypes = .pointOfInterest

        if let response = try? await MKLocalSearch(request: request).start() {
            spots = response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                return Spot(name: name, coordinate: item.placemark.coordinate)
            }
        }
        isLoading = false
    }
}
