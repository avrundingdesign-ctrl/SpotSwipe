import CoreLocation

/// Koordinate als einfacher, sendbarer Werttyp.
nonisolated struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Fallback für Beispieldaten ohne Standort (Kölner Dom).
    static let cologne = GeoPoint(latitude: 50.9413, longitude: 6.9583)
}

nonisolated enum GeoMath {
    static let earthRadius = 6_371_000.0

    /// Luftlinie in Metern (Haversine).
    static func distance(from a: GeoPoint, to b: GeoPoint) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Rechteck, das den Kreis um `center` umschließt. Die Text Search von Google
    /// erlaubt als harte Grenze nur Rechtecke; den Kreis filtern wir danach selbst.
    static func boundingBox(center: GeoPoint, radius: Double) -> (low: GeoPoint, high: GeoPoint) {
        let latDelta = radius / earthRadius * 180 / .pi
        let lonDelta = latDelta / max(cos(center.latitude * .pi / 180), 0.0001)
        return (
            GeoPoint(latitude: max(center.latitude - latDelta, -90), longitude: center.longitude - lonDelta),
            GeoPoint(latitude: min(center.latitude + latDelta, 90), longitude: center.longitude + lonDelta)
        )
    }
}
