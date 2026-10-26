@preconcurrency import MapKit
import Observation

/// Adress-Autovervollständigung über MapKit (kostenlos, ohne Google).
@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet { completer.queryFragment = query }
    }

    private(set) var results: [MKLocalSearchCompletion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Vorschläge in der Nähe bevorzugen.
    func bias(to point: GeoPoint?) {
        guard let point else { return }
        completer.region = MKCoordinateRegion(center: point.coordinate, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> SearchLocation? {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        guard let item = try? await search.start().mapItems.first else { return nil }
        return SearchLocation(
            name: completion.title,
            subtitle: completion.subtitle.isEmpty ? nil : completion.subtitle,
            point: GeoPoint(item.location.coordinate)
        )
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            results = Array(completer.results.prefix(4))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            results = []
        }
    }
}
