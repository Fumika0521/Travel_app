import CoreLocation
import MapKit

/// Real driving-time estimates via `MKDirections` — unlike transit,
/// Apple's road-routing data has broad (not city-limited) coverage, so
/// this works as a genuine free alternative for 車移動 trips, not just a
/// distance/speed guess.
enum DrivingEstimateService {
    static func totalDrivingTime(through coordinates: [CLLocationCoordinate2D]) async -> TimeInterval? {
        guard coordinates.count >= 2 else { return nil }

        var total: TimeInterval = 0
        for (from, to) in zip(coordinates, coordinates.dropFirst()) {
            guard let legTime = await drivingTime(from: from, to: to) else { return nil }
            total += legTime
        }
        return total
    }

    private static func drivingTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile

        guard let response = try? await MKDirections(request: request).calculate(),
              let route = response.routes.first else {
            return nil
        }
        return route.expectedTravelTime
    }
}
