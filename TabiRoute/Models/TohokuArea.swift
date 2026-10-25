import CoreLocation
import Foundation

struct TohokuPrefecture: Identifiable {
    let id: String
    let name: String
    let cities: [String]
}

/// Hand-picked major cities/towns per prefecture — a curated starting
/// point for the area drill-down picker, not an exhaustive municipality
/// list. Matches the app's existing preference for small rule-based
/// tables (see `ClimateService`'s seasonal fallback) over trying to pull
/// administrative-boundary data from a geocoding API that isn't really
/// built for enumerating them.
enum TohokuArea {
    static let prefectures: [TohokuPrefecture] = [
        TohokuPrefecture(id: "aomori", name: "青森県", cities: ["青森市", "弘前市", "八戸市", "十和田市", "五所川原市"]),
        TohokuPrefecture(id: "iwate", name: "岩手県", cities: ["盛岡市", "花巻市", "一関市", "宮古市", "平泉町"]),
        TohokuPrefecture(id: "miyagi", name: "宮城県", cities: ["仙台市", "石巻市", "松島町", "気仙沼市", "大崎市"]),
        TohokuPrefecture(id: "akita", name: "秋田県", cities: ["秋田市", "横手市", "大館市", "男鹿市", "由利本荘市"]),
        TohokuPrefecture(id: "yamagata", name: "山形県", cities: ["山形市", "米沢市", "鶴岡市", "酒田市", "新庄市"]),
        TohokuPrefecture(id: "fukushima", name: "福島県", cities: ["福島市", "会津若松市", "郡山市", "いわき市", "白河市"])
    ]

    /// A rough bounding box around the 6 Tohoku prefectures — intentionally
    /// approximate (not a precise polygon), used only to decide whether to
    /// show an "this looks like it's outside Tohoku" notice, never to hide
    /// or block anything.
    private static let latitudeRange: ClosedRange<Double> = 36.7...41.6
    private static let longitudeRange: ClosedRange<Double> = 139.3...142.2

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
    }
}
