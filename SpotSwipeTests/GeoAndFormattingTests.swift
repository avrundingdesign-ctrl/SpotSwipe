import Foundation
import Testing
@testable import SpotSwipe

struct GeoMathTests {
    @Test func oneDegreeOfLongitudeAtEquatorIsAbout111Kilometers() {
        let distance = GeoMath.distance(from: GeoPoint(latitude: 0, longitude: 0), to: GeoPoint(latitude: 0, longitude: 1))
        #expect(abs(distance - 111_195) < 50)
    }

    @Test func distanceIsSymmetric() {
        let dom = GeoPoint(latitude: 50.9413, longitude: 6.9583)
        let ehrenfeld = GeoPoint(latitude: 50.9497, longitude: 6.9156)
        #expect(abs(GeoMath.distance(from: dom, to: ehrenfeld) - GeoMath.distance(from: ehrenfeld, to: dom)) < 0.001)
    }

    @Test(arguments: [0.0, 90.0, 180.0, 270.0])
    func boundingBoxContainsCircleEdge(bearingDegrees: Double) {
        let center = GeoPoint(latitude: 50.94, longitude: 6.95)
        let radius = 2_000.0
        let box = GeoMath.boundingBox(center: center, radius: radius)

        // Punkt knapp innerhalb des Kreisrands in Richtung `bearing`
        let bearing = bearingDegrees * .pi / 180
        let d = radius * 0.999
        let point = GeoPoint(
            latitude: center.latitude + d * cos(bearing) / GeoMath.earthRadius * 180 / .pi,
            longitude: center.longitude + d * sin(bearing) / GeoMath.earthRadius * 180 / .pi / cos(center.latitude * .pi / 180)
        )

        #expect(point.latitude >= box.low.latitude && point.latitude <= box.high.latitude)
        #expect(point.longitude >= box.low.longitude && point.longitude <= box.high.longitude)
        #expect(GeoMath.distance(from: center, to: point) <= radius)
    }
}

struct FormattersTests {
    @Test func distances() {
        #expect(Formatters.distance(648) == "650 m")
        #expect(Formatters.distance(3) == "10 m")
        #expect(Formatters.distance(1_234) == "1,2 km")
        #expect(Formatters.distance(12_400) == "12 km")
    }

    @Test func radii() {
        #expect(Formatters.radius(500) == "500 m")
        #expect(Formatters.radius(2_000) == "2 km")
        #expect(Formatters.radius(25_000) == "25 km")
    }

    @Test func ratingUsesGermanComma() {
        #expect(Formatters.rating(4.7) == "4,7")
    }

    @Test func openingStatus() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let six = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 18)))
        let halfPast = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 22, minute: 30)))

        #expect(Formatters.openingStatus(isOpen: true, nextClose: six, calendar: calendar) == "Geöffnet · bis 18 Uhr")
        #expect(Formatters.openingStatus(isOpen: true, nextClose: halfPast, calendar: calendar) == "Geöffnet · bis 22:30 Uhr")
        #expect(Formatters.openingStatus(isOpen: false, nextClose: nil) == "Geschlossen")
        #expect(Formatters.openingStatus(isOpen: nil, nextClose: nil) == nil)
    }

    @Test func recentSearchesDeduplicateAndCap() {
        var stored = ""
        for term in ["Café", "Pizza", "café", "  ", "Bar"] {
            stored = RecentSearches.adding(term, to: stored)
        }
        #expect(RecentSearches.decode(stored) == ["Bar", "café", "Pizza"])

        for i in 0..<20 { stored = RecentSearches.adding("Suche \(i)", to: stored) }
        #expect(RecentSearches.decode(stored).count == RecentSearches.limit)
    }
}
