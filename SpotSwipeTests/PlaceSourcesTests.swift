import Foundation
import MapKit
import Testing
@testable import SpotSwipe

struct ProxyPlaceReplyTests {
    private func decode(_ json: String) throws -> ProxyPlaceReply {
        try JSONDecoder().decode(ProxyPlaceReply.self, from: Data(json.utf8))
    }

    @Test func fullReplyBecomesExtras() throws {
        let reply = try decode("""
        {
          "found": true, "rating": 4.6, "ratingCount": 812,
          "priceLevel": "PRICE_LEVEL_MODERATE",
          "openNow": false, "nextCloseTime": "2026-10-26T17:00:00Z",
          "weekdayHours": ["Montag: 08:00–18:00"],
          "photos": [
            { "url": "https://lh3.googleusercontent.com/p/abc", "attribution": "Anna K." },
            { "url": "https://lh3.googleusercontent.com/p/def" }
          ],
          "photoURL": "https://lh3.googleusercontent.com/p/abc"
        }
        """)
        let extras = try #require(reply.extras)
        #expect(extras.rating == 4.6)
        #expect(extras.ratingCount == 812)
        #expect(extras.priceLevel == .moderate)
        #expect(extras.isOpenNow == false, "„geschlossen“ ist eine Auskunft, kein fehlender Wert")
        #expect(extras.nextCloseTime == Date(timeIntervalSince1970: 1_793_034_000))
        #expect(extras.weekdayHours == ["Montag: 08:00–18:00"])
        #expect(extras.photos.count == 2)
        #expect(extras.photos.first?.authorName == "Anna K.")
        #expect(extras.photos.last?.authorName == nil)
    }

    @Test func notFoundHasNoExtras() throws {
        #expect(try decode(#"{"found": false}"#).extras == nil)
    }

    @Test func olderProxyWithoutOpeningHoursStillWorks() throws {
        let extras = try #require(try decode(#"{"found": true, "rating": 4.1}"#).extras)
        #expect(extras.rating == 4.1)
        #expect(extras.isOpenNow == nil)
        #expect(extras.photos.isEmpty)
    }
}

struct PlaceMergingTests {
    private let base = Place(
        id: "x", name: "Café", location: GeoPoint(latitude: 50, longitude: 7),
        rating: 3.0, weekdayHours: ["alt"]
    )

    @Test func extrasOverrideOnlyWhatTheyKnow() {
        let photo = PlacePhoto(url: URL(string: "https://example.com/a.jpg")!)
        let merged = base.merging(PlaceExtras(rating: 4.5, isOpenNow: true, photos: [photo]))
        #expect(merged.rating == 4.5)
        #expect(merged.isOpenNow == true)
        #expect(merged.photos == [photo])
        #expect(merged.weekdayHours == ["alt"], "leere Öffnungszeiten überschreiben nichts")
        #expect(merged.name == "Café")
    }

    @Test func emptyExtrasChangeNothing() {
        #expect(base.merging(PlaceExtras()) == base)
    }
}

@MainActor
struct AppleMapsMappingTests {
    @Test func categoriesAreGerman() {
        #expect(AppleMapsPlacesService.categoryName(for: .cafe) == "Café")
        #expect(AppleMapsPlacesService.categoryName(for: .nightlife) == "Bar")
        #expect(AppleMapsPlacesService.categoryName(for: .bakery) == "Bäckerei")
        #expect(AppleMapsPlacesService.categoryName(for: .atm) == nil)
    }
}
