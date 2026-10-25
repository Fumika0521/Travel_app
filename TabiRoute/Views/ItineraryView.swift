import SwiftUI
import RouteClusteringKit

/// Suggests a visiting order for a trip's photo clusters (nearest-neighbor,
/// not just chronological) and spreads them across the trip's day count —
/// a lightweight "schedule" view, separate from the packing list.
struct ItineraryView: View {
    let clusters: [RouteCluster]
    let dayCount: Int

    @State private var placeNames: [String: String] = [:]
    @State private var isLoading = true

    private var orderedClusters: [RouteCluster] {
        RouteClustering.suggestedVisitOrder(for: clusters)
    }

    private var dayGroups: [[RouteCluster]] {
        distribute(orderedClusters, intoDayCount: max(dayCount, 1))
    }

    var body: some View {
        List {
            ForEach(Array(dayGroups.enumerated()), id: \.offset) { index, group in
                Section("\(index + 1)日目") {
                    ForEach(group) { cluster in
                        Text(placeNames[cluster.id] ?? "読み込み中...")
                    }
                }
            }
        }
        .navigationTitle("予定表の提案")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await loadPlaceNames() }
    }

    private func distribute(_ ordered: [RouteCluster], intoDayCount dayCount: Int) -> [[RouteCluster]] {
        guard !ordered.isEmpty else { return [] }
        let perDay = Int((Double(ordered.count) / Double(dayCount)).rounded(.up))
        var result: [[RouteCluster]] = []
        var index = 0
        while index < ordered.count {
            let end = min(index + perDay, ordered.count)
            result.append(Array(ordered[index..<end]))
            index = end
        }
        return result
    }

    private func loadPlaceNames() async {
        for cluster in orderedClusters where placeNames[cluster.id] == nil {
            placeNames[cluster.id] = await PlacemarkService.placeName(for: cluster.coordinate) ?? "地点"
        }
        isLoading = false
    }
}
