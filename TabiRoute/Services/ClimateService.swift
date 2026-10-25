import CoreLocation
import Foundation

enum ClimateCategory {
    case cold, cool, mild, warm, hot
}

struct ClimateSummary {
    enum Source {
        case forecast
        case seasonalEstimate
    }

    let category: ClimateCategory
    let isRainySeason: Bool
    let source: Source
    /// Only set when `source == .forecast` — the seasonal fallback gives a
    /// category, not fabricated decimal precision.
    let approxHighC: Double?
    let approxLowC: Double?
}

/// Resolves a destination + date range to an expected climate, used to
/// drive packing-list rules. Prefers a real forecast when the trip starts
/// soon (Open-Meteo's free forecast horizon); otherwise falls back to a
/// static seasonal table keyed by rough latitude band + month, since most
/// trips are planned further out than any forecast can reach.
enum ClimateService {
    private static let openMeteoForecastDayLimit = 15

    static func geocode(destinationName: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.geocodeAddressString(destinationName).first,
              let location = placemark.location else {
            return nil
        }
        return location.coordinate
    }

    static func climateSummary(latitude: Double, longitude: Double, startDate: Date, endDate: Date) async -> ClimateSummary {
        if let forecast = await fetchForecast(latitude: latitude, longitude: longitude, startDate: startDate, endDate: endDate) {
            return forecast
        }
        return seasonalEstimate(latitude: latitude, startDate: startDate)
    }

    private static func fetchForecast(latitude: Double, longitude: Double, startDate: Date, endDate: Date) async -> ClimateSummary? {
        let calendar = Calendar.current
        guard let daysAhead = calendar.dateComponents([.day], from: .now, to: startDate).day,
              daysAhead >= 0, daysAhead <= openMeteoForecastDayLimit else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let cappedEndDate = min(endDate, calendar.date(byAdding: .day, value: openMeteoForecastDayLimit, to: .now) ?? endDate)

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: cappedEndDate))
        ]

        guard let url = components.url else { return nil }

        struct Response: Decodable {
            struct Daily: Decodable {
                let temperature_2m_max: [Double]
                let temperature_2m_min: [Double]
                let precipitation_sum: [Double]
            }
            let daily: Daily
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              !decoded.daily.temperature_2m_max.isEmpty else {
            return nil
        }

        let highs = decoded.daily.temperature_2m_max
        let lows = decoded.daily.temperature_2m_min
        let avgHigh = highs.reduce(0, +) / Double(highs.count)
        let avgLow = lows.reduce(0, +) / Double(lows.count)
        let avgDailyPrecipitation = decoded.daily.precipitation_sum.reduce(0, +) / Double(decoded.daily.precipitation_sum.count)

        return ClimateSummary(
            category: category(forAverageHighC: avgHigh),
            isRainySeason: avgDailyPrecipitation >= 5.0,
            source: .forecast,
            approxHighC: avgHigh,
            approxLowC: avgLow
        )
    }

    private static func category(forAverageHighC high: Double) -> ClimateCategory {
        switch high {
        case ..<10: return .cold
        case ..<18: return .cool
        case ..<24: return .mild
        case ..<30: return .warm
        default: return .hot
        }
    }

    // MARK: - Seasonal fallback

    private enum LatitudeBand {
        case north, central, okinawa
    }

    private static func band(forLatitude latitude: Double) -> LatitudeBand {
        if latitude >= 38 { return .north }
        if latitude >= 27 { return .central }
        return .okinawa
    }

    /// (category, isRainySeason) per month, approximated per band from
    /// typical Japan climate averages — intentionally coarse since this is
    /// only a fallback for trips too far out to forecast.
    private static let seasonalTable: [LatitudeBand: [Int: (ClimateCategory, Bool)]] = [
        .north: [
            1: (.cold, false), 2: (.cold, false), 3: (.cool, false), 4: (.cool, false),
            5: (.mild, false), 6: (.mild, false), 7: (.warm, false), 8: (.warm, false),
            9: (.mild, false), 10: (.cool, false), 11: (.cool, false), 12: (.cold, false)
        ],
        .central: [
            1: (.cold, false), 2: (.cold, false), 3: (.cool, false), 4: (.mild, false),
            5: (.mild, false), 6: (.warm, true), 7: (.hot, true), 8: (.hot, false),
            9: (.warm, true), 10: (.mild, false), 11: (.cool, false), 12: (.cold, false)
        ],
        .okinawa: [
            1: (.mild, false), 2: (.mild, false), 3: (.warm, false), 4: (.warm, false),
            5: (.warm, true), 6: (.hot, true), 7: (.hot, false), 8: (.hot, true),
            9: (.hot, true), 10: (.warm, false), 11: (.warm, false), 12: (.mild, false)
        ]
    ]

    private static func seasonalEstimate(latitude: Double, startDate: Date) -> ClimateSummary {
        let month = Calendar.current.component(.month, from: startDate)
        let (category, isRainySeason) = seasonalTable[band(forLatitude: latitude)]?[month] ?? (.mild, false)
        return ClimateSummary(category: category, isRainySeason: isRainySeason, source: .seasonalEstimate, approxHighC: nil, approxLowC: nil)
    }
}
