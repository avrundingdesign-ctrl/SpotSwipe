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
    private let de = Locale(identifier: "de_DE")
    private let en = Locale(identifier: "en_US")

    @Test func distances() {
        #expect(Formatters.distance(648, locale: de) == "650 m")
        #expect(Formatters.distance(3, locale: de) == "10 m")
        #expect(Formatters.distance(1_234, locale: de) == "1,2 km")
        #expect(Formatters.distance(1_234, locale: en) == "1.2 km")
        #expect(Formatters.distance(12_400, locale: de) == "12 km")
    }

    @Test func radii() {
        #expect(Formatters.radius(500, locale: de) == "500 m")
        #expect(Formatters.radius(2_000, locale: de) == "2 km")
        #expect(Formatters.radius(25_000, locale: de) == "25 km")
        #expect(Formatters.radiusTick(500, isLast: false, locale: de) == "0,5")
        #expect(Formatters.radiusTick(500, isLast: false, locale: en) == "0.5")
        #expect(Formatters.radiusTick(25_000, isLast: true, locale: de) == "25 km")
    }

    @Test func ratingFollowsLocale() {
        #expect(Formatters.rating(4.7, locale: de) == "4,7")
        #expect(Formatters.rating(4.7, locale: en) == "4.7")
    }

    @Test func openingStatus() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        let six = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 18)))
        let halfPast = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 22, minute: 30)))

        #expect(Formatters.openingStatus(isOpen: true, nextClose: six, locale: de, timeZone: berlin) == "Geöffnet · bis 18:00")
        #expect(Formatters.openingStatus(isOpen: true, nextClose: halfPast, locale: de, timeZone: berlin) == "Geöffnet · bis 22:30")
        #expect(Formatters.openingStatus(isOpen: true, nextClose: nil) == "Geöffnet")
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
