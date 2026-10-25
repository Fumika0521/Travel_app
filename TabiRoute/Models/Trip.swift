import Foundation
import SwiftData

/// Persisted trip metadata. Deliberately does not duplicate coordinates or
/// thumbnails — those are re-derived from Photos via `assetIdentifiers` each
/// time the trip is opened, via `PhotoLibraryService`.
@Model
final class Trip {
    var id: UUID
    var name: String
    var createdAt: Date
    var assetIdentifiers: [String]
    /// Places added via search instead of photos — e.g. for a trip
    /// created without any photos yet. Rendered on the map alongside
    /// (but kept separate from) the photo-derived route.
    var manualWaypoints: [ManualWaypoint] = []
    var transportModeRawValue: String = TransportMode.transit.rawValue

    var transportMode: TransportMode {
        get { TransportMode(rawValue: transportModeRawValue) ?? .transit }
        set { transportModeRawValue = newValue.rawValue }
    }

    init(name: String, assetIdentifiers: [String], createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.assetIdentifiers = assetIdentifiers
        self.createdAt = createdAt
    }
}
