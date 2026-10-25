import Combine
import MapKit

/// Bridges `MKLocalSearchCompleter`'s delegate callbacks into SwiftUI —
/// gives live, as-you-type place suggestions instead of needing to submit
/// before anything shows up.
final class PlaceSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }

    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func update(queryFragment: String) {
        completer.queryFragment = queryFragment
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
