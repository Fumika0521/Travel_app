import CoreLocation
import Foundation

/// A map point added via search instead of derived from a photo — stored
/// as plain Codable data on `Trip` (SwiftData persists Codable value types
/// directly, no separate model/relationship needed).
struct ManualWaypoint: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
