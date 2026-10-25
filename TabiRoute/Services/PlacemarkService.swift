import CoreLocation

struct PlacemarkDetails {
    let name: String?
    /// ISO 3166-1 alpha-2 country code (e.g. "JP") — used to tell domestic
    /// from international destinations for packing-list rules.
    let isoCountryCode: String?
}

/// Resolves a coordinate to a human-readable area name (and country) via
/// Apple's reverse-geocoding service — surfaces the neighborhood/city a
/// cluster of photos was taken in, which a thumbnail alone doesn't tell
/// the user.
enum PlacemarkService {
    static func details(for coordinate: CLLocationCoordinate2D) async -> PlacemarkDetails {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return PlacemarkDetails(name: nil, isoCountryCode: nil)
        }

        let name: String?
        if let locality = placemark.locality {
            name = placemark.subLocality.map { "\(locality)\($0)" } ?? locality
        } else {
            name = placemark.name
        }
        return PlacemarkDetails(name: name, isoCountryCode: placemark.isoCountryCode)
    }

    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        await details(for: coordinate).name
    }
}
