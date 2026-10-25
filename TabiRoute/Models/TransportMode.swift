import Foundation

/// How the user plans to get between stops on this trip — drives which
/// Apple Maps direction flag is used, whether 道の駅 show up as recommended
/// spots, and whether a driving-time estimate is computed.
enum TransportMode: String, CaseIterable, Identifiable, Codable {
    case car = "車移動"
    case transit = "公共交通機関"

    var id: String { rawValue }
}
