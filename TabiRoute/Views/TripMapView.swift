import SwiftUI
import MapKit
import RouteClusteringKit

/// A nearby point of interest surfaced from `MKLocalSearch` — not a place
/// the user has photos of, so it's rendered with a distinct marker from
/// the red photo-cluster pins to invite "there's also this place" discovery.
struct RecommendedSpot: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

/// Unifies the three marker kinds under one `Map(selection:)` binding so
/// tapping any of them (not just photo clusters) surfaces something.
private enum MapSelection: Hashable {
    case cluster(String)
    case spot(UUID)
    case waypoint(UUID)
}

/// A round flat badge for a route's departure/destination endpoints —
/// deliberately not a teardrop `Marker` pin, which is what both Apple
/// Maps and Google Maps use and was read as "too Google Maps".
private struct RouteEndpointBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 32, height: 32)
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(radius: 2, y: 1)
    }
}

struct TripMapView: View {
    let trip: Trip

    @Environment(\.openURL) private var openURL

    @State private var geoPoints: [GeoPoint] = []
    @State private var clusters: [RouteCluster] = []
    @State private var recommendedSpots: [RecommendedSpot] = []
    @State private var manualWaypoints: [ManualWaypoint] = []
    @State private var missingLocationCount = 0
    @State private var permissionDenied = false
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selection: MapSelection?
    @State private var isRenamingTrip = false
    @State private var editedTripName = ""
    @State private var isShowingItinerary = false
    @State private var drivingEstimateSeconds: TimeInterval?
    @State private var isLoadingDrivingEstimate = false
    @State private var recommendedSpotsRegion: MKCoordinateRegion?
    @State private var hasOutOfAreaPhotos = false

    private var selectedCluster: RouteCluster? {
        guard case .cluster(let id) = selection else { return nil }
        return clusters.first { $0.id == id }
    }

    private var selectedSpot: RecommendedSpot? {
        guard case .spot(let id) = selection else { return nil }
        return recommendedSpots.first { $0.id == id }
    }

    private var selectedWaypoint: ManualWaypoint? {
        guard case .waypoint(let id) = selection else { return nil }
        return manualWaypoints.first { $0.id == id }
    }

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openTransitDirections()
                } label: {
                    Label("経路をApple Mapsで開く", systemImage: trip.transportMode == .car ? "car.fill" : "tram.fill")
                }
                .disabled(transitRouteCoordinates.count < 2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItinerary = true
                } label: {
                    Label("予定表の提案", systemImage: "list.number")
                }
                .disabled(clusters.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editedTripName = trip.name
                    isRenamingTrip = true
                } label: {
                    Label("名前を変更", systemImage: "pencil")
                }
            }
        }
        .alert("トリップ名を変更", isPresented: $isRenamingTrip) {
            TextField("トリップ名", text: $editedTripName)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                let trimmed = editedTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                trip.name = trimmed
            }
        }
        .sheet(isPresented: $isShowingItinerary) {
            NavigationStack {
                ItineraryView(clusters: clusters, dayCount: totalDayCount)
            }
        }
        .alert("東北地方以外の写真が含まれています", isPresented: $hasOutOfAreaPhotos) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("このトリップの写真の中に、東北6県の範囲外で撮影されたものがあるようです。写真はそのまま表示されます。")
        }
        .task { await loadData() }
        .onChange(of: trip.transportMode) {
            Task { await reloadModeDependentData() }
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selection) {
            if geoPoints.count > 1 {
                MapPolyline(coordinates: geoPoints.sorted { $0.date < $1.date }.map(\.coordinate))
                    .stroke(.blue, lineWidth: 3)
            }
            if manualWaypoints.count > 1 {
                MapPolyline(coordinates: manualWaypoints.map(\.coordinate))
                    .stroke(.purple, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
            }
            ForEach(clusters) { cluster in
                Marker(cluster.photoCount > 1 ? "\(cluster.photoCount)枚" : "", coordinate: cluster.coordinate)
                    .tint(.red)
                    .tag(MapSelection.cluster(cluster.id))
            }
            ForEach(recommendedSpots) { spot in
                Marker(spot.name, systemImage: "star.fill", coordinate: spot.coordinate)
                    .tint(.orange)
                    .tag(MapSelection.spot(spot.id))
            }
            ForEach(manualWaypoints) { waypoint in
                let index = manualWaypoints.firstIndex(of: waypoint)
                if index == 0 {
                    Annotation(waypoint.name, coordinate: waypoint.coordinate) {
                        RouteEndpointBadge(systemImage: "figure.walk", color: .green)
                    }
                    .tag(MapSelection.waypoint(waypoint.id))
                } else if index == manualWaypoints.count - 1 {
                    Annotation(waypoint.name, coordinate: waypoint.coordinate) {
                        RouteEndpointBadge(systemImage: "flag.checkered", color: .purple)
                    }
                    .tag(MapSelection.waypoint(waypoint.id))
                } else {
                    Marker(waypoint.name, systemImage: "mappin", coordinate: waypoint.coordinate)
                        .tint(.blue)
                        .tag(MapSelection.waypoint(waypoint.id))
                }
            }
        }
        // `.muted` desaturates the base map (roads/land/labels go grayish)
        // so only our own colored markers read as "information" — closer
        // to the Tabelog-style "quiet background, bold pins" look than
        // default Apple Maps, still free/native (no custom tile vendor).
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .safeAreaInset(edge: .top) {
            summaryBar
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedCluster {
                ClusterPhotosView(cluster: selectedCluster) {
                    selection = nil
                }
            } else if let selectedSpot {
                RecommendedSpotCard(spot: selectedSpot) {
                    selection = nil
                }
            } else if let selectedWaypoint {
                waypointCard(for: selectedWaypoint)
            } else if missingLocationCount > 0 {
                Text("位置情報のない写真が\(missingLocationCount)枚あります")
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
        }
    }

    /// Shown when a waypoint marker is tapped. The main toolbar button
    /// always routes from the very first stop, which doesn't help once
    /// you've already arrived partway through — so this adds two
    /// per-stop shortcuts: the leg that got you here, and the remaining
    /// leg from here to the final destination.
    private func waypointCard(for waypoint: ManualWaypoint) -> some View {
        let index = manualWaypoints.firstIndex(of: waypoint)
        let directionsIcon = trip.transportMode == .car ? "car.fill" : "tram.fill"

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: waypointIcon(for: waypoint)).foregroundStyle(waypointTint(for: waypoint))
                Text(waypoint.name).font(.footnote.bold())
                Spacer()
                Button {
                    selection = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if let index, index > 0 {
                Button {
                    openDirections(from: manualWaypoints[index - 1].coordinate, to: waypoint.coordinate)
                } label: {
                    Label("\(manualWaypoints[index - 1].name)からの経路を開く", systemImage: directionsIcon)
                }
                .buttonStyle(.bordered)
            }

            if let index, index < manualWaypoints.count - 1, let destination = manualWaypoints.last {
                Button {
                    openDirections(from: waypoint.coordinate, to: destination.coordinate)
                } label: {
                    Label("目的地までの経路を開く", systemImage: directionsIcon)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(8)
        .background(.thinMaterial)
    }

    private func openDirections(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        guard let url = AppleMapsDirections.directionsURL(through: [from, to], mode: trip.transportMode) else { return }
        openURL(url)
    }

    private var summaryBar: some View {
        VStack(spacing: 8) {
            Picker("移動手段", selection: Binding(
                get: { trip.transportMode },
                set: { trip.transportMode = $0 }
            )) {
                ForEach(TransportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                summaryItem(systemImage: "point.topleft.down.curvedto.point.filled.bottomright.up", text: distanceSummaryText)
                summaryItem(systemImage: "calendar", text: daySummaryText)
                summaryItem(systemImage: "mappin", text: "\(clusters.count)地点")
                if trip.transportMode == .car {
                    if isLoadingDrivingEstimate {
                        summaryItem(systemImage: "car.fill", text: "計算中...")
                    } else if let drivingEstimateSeconds {
                        summaryItem(systemImage: "car.fill", text: drivingEstimateText(for: drivingEstimateSeconds))
                    }
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }

    private func drivingEstimateText(for seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: seconds).map { "運転\($0)" } ?? ""
    }

    private func summaryItem(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
    }

    private var distanceSummaryText: String {
        let meters = RouteClustering.totalDistance(points: geoPoints)
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .narrow, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }

    private var daySummaryText: String {
        guard let first = geoPoints.map(\.date).min(), let last = geoPoints.map(\.date).max() else {
            return "0日間"
        }
        let calendar = Calendar.current
        // Exclusive end one day past `last` so the inclusive day count falls
        // out of calendar-accurate month/day components directly, without a
        // separate "+1" step that would need its own month-length handling.
        let inclusiveEnd = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        let components = calendar.dateComponents([.month, .day], from: first, to: inclusiveEnd)
        let months = components.month ?? 0
        let days = components.day ?? 0

        if months > 0 {
            return days > 0 ? "\(months)ヶ月\(days)日間" : "\(months)ヶ月間"
        }
        return "\(days)日間"
    }

    /// Manual waypoints are an ordered route (出発地 → 行きたい場所 → 目的地),
    /// so the first/last get distinct icons matching the map's
    /// `RouteEndpointBadge` styling, with stops in between using "mappin".
    private func waypointIcon(for waypoint: ManualWaypoint) -> String {
        guard let index = manualWaypoints.firstIndex(of: waypoint) else { return "mappin" }
        if index == 0 { return "figure.walk" }
        if index == manualWaypoints.count - 1 { return "flag.checkered" }
        return "mappin"
    }

    private func waypointTint(for waypoint: ManualWaypoint) -> Color {
        guard let index = manualWaypoints.firstIndex(of: waypoint) else { return .blue }
        if index == 0 { return .green }
        if index == manualWaypoints.count - 1 { return .purple }
        return .blue
    }

    /// Prefers the manually-built route (its order is deliberate: 出発地 →
    /// 行きたい場所 → 目的地) when there is one; otherwise chains the photo
    /// clusters in their chronological order.
    private var transitRouteCoordinates: [CLLocationCoordinate2D] {
        if manualWaypoints.count >= 2 {
            return manualWaypoints.map(\.coordinate)
        }
        return clusters.map(\.coordinate)
    }

    private func openTransitDirections() {
        guard let url = AppleMapsDirections.directionsURL(through: transitRouteCoordinates, mode: trip.transportMode) else { return }
        openURL(url)
    }

    private var totalDayCount: Int {
        guard let first = geoPoints.map(\.date).min(), let last = geoPoints.map(\.date).max() else {
            return 1
        }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return days + 1
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView(
            "写真へのアクセスが必要です",
            systemImage: "lock",
            description: Text("設定アプリでこのアプリの写真アクセスを許可すると、ルート地図を作成できます")
        )
    }

    private func loadData() async {
        if !trip.assetIdentifiers.isEmpty {
            guard await PhotoLibraryService.requestReadAccess() else {
                permissionDenied = true
                isLoading = false
                return
            }
        }

        let data = trip.assetIdentifiers.isEmpty
            ? TripPhotoData(geoPoints: [], missingLocationCount: 0)
            : PhotoLibraryService.loadTripPhotoData(assetIdentifiers: trip.assetIdentifiers)

        geoPoints = data.geoPoints
        missingLocationCount = data.missingLocationCount
        clusters = RouteClustering.cluster(points: data.geoPoints)
        manualWaypoints = trip.manualWaypoints
        hasOutOfAreaPhotos = data.geoPoints.contains { !TohokuArea.contains($0.coordinate) }

        let allCoordinates = data.geoPoints.map(\.coordinate) + trip.manualWaypoints.map(\.coordinate)
        if let region = regionCovering(coordinates: allCoordinates) {
            cameraPosition = .region(region)
            recommendedSpotsRegion = region
        }
        await reloadModeDependentData()
        isLoading = false
    }

    /// Re-runs the parts of the screen that depend on 車移動/公共交通機関:
    /// the recommended-spot search query (道の駅 only matters for driving)
    /// and the driving-time estimate. Triggered on load and whenever the
    /// transport-mode picker changes.
    private func reloadModeDependentData() async {
        if let recommendedSpotsRegion {
            recommendedSpots = await fetchRecommendedSpots(in: recommendedSpotsRegion, excludingNear: clusters, mode: trip.transportMode)
        }

        guard trip.transportMode == .car, manualWaypoints.count >= 2 else {
            drivingEstimateSeconds = nil
            return
        }
        isLoadingDrivingEstimate = true
        drivingEstimateSeconds = await DrivingEstimateService.totalDrivingTime(through: manualWaypoints.map(\.coordinate))
        isLoadingDrivingEstimate = false
    }

    /// Searches MapKit's own POI data (no API key needed) for sightseeing
    /// spots (and, when traveling by car, 道の駅) in the trip's bounding
    /// region, excluding anything close to a photo cluster — those are
    /// already "visited", not a discovery.
    private func fetchRecommendedSpots(in region: MKCoordinateRegion, excludingNear clusters: [RouteCluster], mode: TransportMode) async -> [RecommendedSpot] {
        var queries = ["観光スポット"]
        if mode == .car {
            queries.append("道の駅")
        }

        var spots: [RecommendedSpot] = []
        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest

            guard let response = try? await MKLocalSearch(request: request).start() else { continue }

            let newSpots = response.mapItems.compactMap { item -> RecommendedSpot? in
                guard let name = item.name else { return nil }
                let coordinate = item.placemark.coordinate
                let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                let isAlreadyVisited = clusters.contains { cluster in
                    let clusterLocation = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
                    return itemLocation.distance(from: clusterLocation) <= 150
                }
                let isAlreadyFound = spots.contains { spot in
                    let spotLocation = CLLocation(latitude: spot.coordinate.latitude, longitude: spot.coordinate.longitude)
                    return itemLocation.distance(from: spotLocation) <= 150
                }
                return (isAlreadyVisited || isAlreadyFound) ? nil : RecommendedSpot(name: name, coordinate: coordinate)
            }
            spots += newSpots
        }

        return Array(spots.prefix(8))
    }

    private func regionCovering(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
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
