import SwiftUI
import MapKit
import RouteClusteringKit

struct TripMapView: View {
    let trip: Trip

    @State private var geoPoints: [GeoPoint] = []
    @State private var clusters: [RouteCluster] = []
    @State private var missingLocationCount = 0
    @State private var permissionDenied = false
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if permissionDenied {
                permissionDeniedView
            } else if isLoading {
                ProgressView("読み込み中...")
            } else {
                mapView
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            if geoPoints.count > 1 {
                MapPolyline(coordinates: geoPoints.sorted { $0.date < $1.date }.map(\.coordinate))
                    .stroke(.blue, lineWidth: 3)
            }
            ForEach(clusters) { cluster in
                Marker(cluster.photoCount > 1 ? "\(cluster.photoCount)枚" : "", coordinate: cluster.coordinate)
                    .tint(.red)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if missingLocationCount > 0 {
                Text("位置情報のない写真が\(missingLocationCount)枚あります")
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView(
            "写真へのアクセスが必要です",
            systemImage: "lock",
            description: Text("設定アプリでこのアプリの写真アクセスを許可すると、ルート地図を作成できます")
        )
    }

    private func loadData() async {
        guard await PhotoLibraryService.requestReadAccess() else {
            permissionDenied = true
            isLoading = false
            return
        }

        let data = PhotoLibraryService.loadTripPhotoData(assetIdentifiers: trip.assetIdentifiers)
        geoPoints = data.geoPoints
        missingLocationCount = data.missingLocationCount
        clusters = RouteClustering.cluster(points: data.geoPoints)
        if let region = regionCovering(points: data.geoPoints) {
            cameraPosition = .region(region)
        }
        isLoading = false
    }

    private func regionCovering(points: [GeoPoint]) -> MKCoordinateRegion? {
        guard !points.isEmpty else { return nil }
        let lats = points.map(\.coordinate.latitude)
        let lons = points.map(\.coordinate.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
