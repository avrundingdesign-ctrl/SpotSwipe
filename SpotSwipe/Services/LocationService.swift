import CoreLocation
@preconcurrency import MapKit
import Observation

/// Aktueller Standort plus lesbarer Ortsname für den Standort-Chip.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var currentPoint: GeoPoint?
    private(set) var currentPlaceName: String?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// Fragt beim ersten Mal nach der Berechtigung, danach wird nur der Standort aktualisiert.
    func start() {
        switch authorization {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized { self.manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let point = GeoPoint(coordinate)
        Task { @MainActor in await self.update(to: point) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // requestLocation meldet z. B. im Simulator ohne gesetzten Ort einen Fehler; dann bleibt es beim alten Wert.
    }

    private func update(to point: GeoPoint) async {
        let previous = currentPoint
        currentPoint = point
        if let previous, currentPlaceName != nil, GeoMath.distance(from: previous, to: point) < 300 { return }
        currentPlaceName = await Geocoder.address(for: point)?.city
    }
}

/// Rückwärts-Geokodierung über MapKit (kostenlos, ohne Google).
enum Geocoder {
    struct Address: Equatable {
        var title: String
        var city: String?
    }

    static func address(for point: GeoPoint) async -> Address? {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = Formatters.locale
        guard let item = try? await request.mapItems.first else { return nil }
        let city = item.addressRepresentations?.cityName
        let title = item.address?.shortAddress ?? item.name ?? city ?? "Gewählter Ort"
        return Address(title: title, city: city)
    }
}
