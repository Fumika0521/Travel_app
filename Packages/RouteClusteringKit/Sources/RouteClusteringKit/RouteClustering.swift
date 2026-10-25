import CoreLocation

/// A single photo's extracted location, used as input to clustering.
public struct GeoPoint: Identifiable, Equatable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let date: Date

    public init(id: String, coordinate: CLLocationCoordinate2D, date: Date) {
        self.id = id
        self.coordinate = coordinate
        self.date = date
    }

    public static func == (lhs: GeoPoint, rhs: GeoPoint) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.date == rhs.date
    }
}

/// A map marker representing one or more nearby photos, so dense shooting
/// locations (e.g. many photos at the same restaurant) don't overlap as
/// separate pins.
public struct RouteCluster: Identifiable, Equatable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let memberIDs: [String]
    public let earliestDate: Date

    public var photoCount: Int { memberIDs.count }

    public static func == (lhs: RouteCluster, rhs: RouteCluster) -> Bool {
        lhs.id == rhs.id && lhs.memberIDs == rhs.memberIDs
    }
}

public enum RouteClustering {
    /// Groups points that are within `thresholdMeters` of an existing
    /// cluster's running centroid into a single `RouteCluster`. Clusters are
    /// returned ordered by the earliest photo date among their members, so
    /// the result reflects chronological trip order.
    ///
    /// This only affects marker display — the route polyline should still
    /// be drawn through every individual point, not the cluster centroids.
    public static func cluster(points: [GeoPoint], thresholdMeters: CLLocationDistance = 100) -> [RouteCluster] {
        guard !points.isEmpty else { return [] }

        struct MutableCluster {
            var centroid: CLLocationCoordinate2D
            var memberIDs: [String]
            var earliestDate: Date
        }

        let sorted = points.sorted { $0.date < $1.date }
        var clusters: [MutableCluster] = []

        for point in sorted {
            let pointLocation = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)

            if let index = clusters.firstIndex(where: { cluster in
                let clusterLocation = CLLocation(latitude: cluster.centroid.latitude, longitude: cluster.centroid.longitude)
                return pointLocation.distance(from: clusterLocation) <= thresholdMeters
            }) {
                var cluster = clusters[index]
                let newCount = Double(cluster.memberIDs.count + 1)
                let oldCount = Double(cluster.memberIDs.count)
                cluster.centroid = CLLocationCoordinate2D(
                    latitude: (cluster.centroid.latitude * oldCount + point.coordinate.latitude) / newCount,
                    longitude: (cluster.centroid.longitude * oldCount + point.coordinate.longitude) / newCount
                )
                cluster.memberIDs.append(point.id)
                cluster.earliestDate = min(cluster.earliestDate, point.date)
                clusters[index] = cluster
            } else {
                clusters.append(MutableCluster(centroid: point.coordinate, memberIDs: [point.id], earliestDate: point.date))
            }
        }

        return clusters
            .sorted { $0.earliestDate < $1.earliestDate }
            .map { cluster in
                RouteCluster(
                    id: cluster.memberIDs[0],
                    coordinate: cluster.centroid,
                    memberIDs: cluster.memberIDs,
                    earliestDate: cluster.earliestDate
                )
            }
    }

    /// Sums the great-circle distance between consecutive points in
    /// chronological order — the length of the route polyline drawn on the
    /// map, not a straight line between the first and last point.
    public static func totalDistance(points: [GeoPoint]) -> CLLocationDistance {
        guard points.count > 1 else { return 0 }

        let sorted = points.sorted { $0.date < $1.date }
        var total: CLLocationDistance = 0

        for (previous, current) in zip(sorted, sorted.dropFirst()) {
            let from = CLLocation(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude)
            let to = CLLocation(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
            total += from.distance(from: to)
        }

        return total
    }

    /// Greedy nearest-neighbor ordering of clusters, starting from the
    /// chronologically earliest one — a simple, rule-based stand-in for a
    /// real route-optimization algorithm, good enough for the handful of
    /// clusters a single trip produces. Used to suggest a visiting order
    /// for places from a photo selection, as distinct from the clusters'
    /// natural earliest-date order.
    public static func suggestedVisitOrder(for clusters: [RouteCluster]) -> [RouteCluster] {
        guard !clusters.isEmpty else { return [] }

        var remaining = clusters
        var ordered: [RouteCluster] = [remaining.removeFirst()]

        while !remaining.isEmpty {
            let currentLocation = CLLocation(latitude: ordered.last!.coordinate.latitude, longitude: ordered.last!.coordinate.longitude)
            let nextIndex = remaining.indices.min { lhsIndex, rhsIndex in
                let lhsLocation = CLLocation(latitude: remaining[lhsIndex].coordinate.latitude, longitude: remaining[lhsIndex].coordinate.longitude)
                let rhsLocation = CLLocation(latitude: remaining[rhsIndex].coordinate.latitude, longitude: remaining[rhsIndex].coordinate.longitude)
                return currentLocation.distance(from: lhsLocation) < currentLocation.distance(from: rhsLocation)
            }!
            ordered.append(remaining.remove(at: nextIndex))
        }

        return ordered
    }
}
