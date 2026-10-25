import Foundation
import SwiftData

/// A packing list derived from an existing `Trip`'s photos — destination,
/// dates and coordinate are all read off that trip's photo locations/dates
/// rather than typed in, so creating one is closer to "pick a trip" than
/// "fill out a form". The checklist itself is regenerated each time from
/// `PackingListGenerator` so rule changes don't need data migration.
@Model
final class PackingPlan {
    var id: UUID
    var sourceTripID: UUID?
    var destinationName: String
    var destinationIsoCountryCode: String?
    var latitude: Double
    var longitude: Double
    var startDate: Date
    var endDate: Date
    var tripTypeRawValue: String
    var createdAt: Date
    var checkedItemIDs: [String]

    var tripType: TripType {
        TripType(rawValue: tripTypeRawValue) ?? .sightseeing
    }

    /// Defaults to domestic (Japan) when the country couldn't be resolved,
    /// so a geocoding hiccup doesn't wrongly surface passport/adapter items.
    var isInternational: Bool {
        guard let code = destinationIsoCountryCode else { return false }
        return code != "JP"
    }

    init(
        sourceTripID: UUID?,
        destinationName: String,
        destinationIsoCountryCode: String?,
        latitude: Double,
        longitude: Double,
        startDate: Date,
        endDate: Date,
        tripType: TripType,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.sourceTripID = sourceTripID
        self.destinationName = destinationName
        self.destinationIsoCountryCode = destinationIsoCountryCode
        self.latitude = latitude
        self.longitude = longitude
        self.startDate = startDate
        self.endDate = endDate
        self.tripTypeRawValue = tripType.rawValue
        self.createdAt = createdAt
        self.checkedItemIDs = []
    }
}
