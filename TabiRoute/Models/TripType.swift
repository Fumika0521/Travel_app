import Foundation

enum TripType: String, CaseIterable, Identifiable, Codable {
    case sightseeing = "観光"
    case business = "ビジネス"
    case outdoor = "アウトドア"
    case onsen = "温泉・リラックス"

    var id: String { rawValue }
}
