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

    init(name: String, assetIdentifiers: [String], createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.assetIdentifiers = assetIdentifiers
        self.createdAt = createdAt
    }
}
