import XCTest
import CoreLocation
@testable import RouteClusteringKit

final class RouteClusteringTests: XCTestCase {
    private func point(_ id: String, _ lat: Double, _ lon: Double, secondsFromStart offset: TimeInterval) -> GeoPoint {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return GeoPoint(id: id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), date: start.addingTimeInterval(offset))
    }

    func testEmptyInputReturnsEmptyOutput() {
        XCTAssertEqual(RouteClustering.cluster(points: []), [])
    }

    func testFarApartPointsStayAsSeparateClusters() {
        let points = [
            point("tokyo", 35.681236, 139.767125, secondsFromStart: 0),
            point("osaka", 34.693738, 135.502165, secondsFromStart: 3600)
        ]

        let clusters = RouteClustering.cluster(points: points, thresholdMeters: 100)

        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.photoCount), [1, 1])
    }

    func testNearbyPointsMergeIntoOneCluster() {
        // Three photos taken a few meters apart at the same restaurant.
        let points = [
            point("a", 35.681236, 139.767125, secondsFromStart: 0),
            point("b", 35.681240, 139.767130, secondsFromStart: 60),
            point("c", 35.681230, 139.767120, secondsFromStart: 120)
        ]

        let clusters = RouteClustering.cluster(points: points, thresholdMeters: 100)

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].photoCount, 3)
        XCTAssertEqual(Set(clusters[0].memberIDs), Set(["a", "b", "c"]))
    }

    func testClustersAreOrderedByEarliestMemberDate() {
        let points = [
            point("later", 34.693738, 135.502165, secondsFromStart: 7200),
            point("earlier", 35.681236, 139.767125, secondsFromStart: 0)
        ]

        let clusters = RouteClustering.cluster(points: points, thresholdMeters: 100)

        XCTAssertEqual(clusters.map(\.id), ["earlier", "later"])
    }

    func testClusterCentroidIsAverageOfMembers() {
        let points = [
            point("a", 0.0, 0.0, secondsFromStart: 0),
            point("b", 0.001, 0.001, secondsFromStart: 60)
        ]

        let clusters = RouteClustering.cluster(points: points, thresholdMeters: 1000)

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].coordinate.latitude, 0.0005, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].coordinate.longitude, 0.0005, accuracy: 0.0001)
    }

    func testTotalDistanceOfEmptyOrSinglePointIsZero() {
        XCTAssertEqual(RouteClustering.totalDistance(points: []), 0)
        XCTAssertEqual(RouteClustering.totalDistance(points: [point("a", 0, 0, secondsFromStart: 0)]), 0)
    }

    func testTotalDistanceSumsConsecutiveLegsInChronologicalOrder() {
        // Tokyo -> Osaka is roughly 400km; fed out of order to confirm
        // the function sorts by date before summing legs.
        let points = [
            point("osaka", 34.693738, 135.502165, secondsFromStart: 3600),
            point("tokyo", 35.681236, 139.767125, secondsFromStart: 0)
        ]

        let distance = RouteClustering.totalDistance(points: points)

        XCTAssertEqual(distance, 403_000, accuracy: 10_000)
    }

    func testSuggestedVisitOrderOfEmptyInputIsEmpty() {
        XCTAssertEqual(RouteClustering.suggestedVisitOrder(for: []), [])
    }

    func testSuggestedVisitOrderPicksNearestNextRatherThanChronological() {
        // Yokohama is ~30km from Tokyo; Osaka is ~400km. Chronological
        // order is tokyo -> osaka -> yokohama, but the nearest-neighbor
        // order should visit the close Yokohama before backtracking to
        // the far Osaka.
        let points = [
            point("tokyo", 35.681236, 139.767125, secondsFromStart: 0),
            point("osaka", 34.693738, 135.502165, secondsFromStart: 3600),
            point("yokohama", 35.443708, 139.638026, secondsFromStart: 7200)
        ]
        let clusters = RouteClustering.cluster(points: points, thresholdMeters: 100)
        XCTAssertEqual(clusters.map(\.id), ["tokyo", "osaka", "yokohama"])

        let ordered = RouteClustering.suggestedVisitOrder(for: clusters)

        XCTAssertEqual(ordered.map(\.id), ["tokyo", "yokohama", "osaka"])
    }
}
