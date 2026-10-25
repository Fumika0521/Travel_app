import CoreLocation
import Foundation

/// Hands off to the Apple Maps app for real public-transit directions —
/// Apple's own transit/rail data (where it's covered) is something this
/// app has no free way to replicate itself. No API key, no cost.
enum AppleMapsDirections {
    /// A URL requesting directions through an ordered chain of 2+ stops
    /// (saddr → daddr, with any middle stops joined via Apple Maps'
    /// documented "+to:" multi-stop syntax), in the given transport mode.
    static func directionsURL(through coordinates: [CLLocationCoordinate2D], mode: TransportMode) -> URL? {
        guard coordinates.count >= 2 else { return nil }

        var components = URLComponents(string: "https://maps.apple.com/")!
        let destinationAddress = coordinates.dropFirst()
            .map(address(for:))
            .joined(separator: "+to:")

        components.queryItems = [
            URLQueryItem(name: "saddr", value: address(for: coordinates[0])),
            URLQueryItem(name: "daddr", value: destinationAddress),
            URLQueryItem(name: "dirflg", value: mode == .car ? "d" : "r")
        ]
        return components.url
    }

    private static func address(for coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}
