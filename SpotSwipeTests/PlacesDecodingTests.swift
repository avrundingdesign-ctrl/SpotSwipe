import Foundation
import Testing
@testable import SpotSwipe

struct PlacesDecodingTests {
    /// Gekürzte, echte Antwortform der Text Search (New).
    private let json = """
    {
      "places": [
        {
          "id": "ChIJ123",
          "displayName": { "text": "Café Liebling", "languageCode": "de" },
          "formattedAddress": "Venloer Str. 210, 50823 Köln, Deutschland",
          "shortFormattedAddress": "Venloer Str. 210, Köln",
          "location": { "latitude": 50.9497, "longitude": 6.9156 },
          "rating": 4.7,
          "userRatingCount": 812,
          "priceLevel": "PRICE_LEVEL_MODERATE",
          "currentOpeningHours": { "openNow": true, "nextCloseTime": "2026-10-26T17:00:00Z" },
          "regularOpeningHours": { "weekdayDescriptions": ["Montag: 08:00–18:00"] },
          "nationalPhoneNumber": "0221 1234567",
          "websiteUri": "https://example.com/",
          "googleMapsUri": "https://maps.google.com/?cid=1",
          "primaryTypeDisplayName": { "text": "Café", "languageCode": "de" },
          "photos": [
            {
              "name": "places/ChIJ123/photos/AAA",
              "widthPx": 4032,
              "heightPx": 3024,
              "authorAttributions": [ { "displayName": "Anna K.", "uri": "https://maps.google.com/maps/contrib/1" } ]
            }
          ]
        },
        { "id": "NoLocation", "displayName": { "text": "Ohne Koordinate" } }
      ]
    }
    """

    @Test func mapsSearchResponseToPlaces() throws {
        let response = try GooglePlacesCoding.decoder.decode(SearchTextResponse.self, from: Data(json.utf8))
        let places = (response.places ?? []).compactMap(\.place)

        #expect(places.count == 1, "Orte ohne Koordinate werden verworfen")
        let place = try #require(places.first)
        #expect(place.id == "ChIJ123")
        #expect(place.name == "Café Liebling")
        #expect(place.category == "Café")
        #expect(place.priceLevel == .moderate)
        #expect(place.priceLevel?.symbol == "€€")
        #expect(place.rating == 4.7)
        #expect(place.userRatingCount == 812)
        #expect(place.isOpenNow == true)
        #expect(place.nextCloseTime != nil)
        #expect(place.weekdayHours == ["Montag: 08:00–18:00"])
        #expect(place.phoneURL?.absoluteString == "tel:02211234567")
        #expect(place.photos.first?.name == "places/ChIJ123/photos/AAA")
        #expect(place.photos.first?.authorName == "Anna K.")
        #expect(place.shareURL.absoluteString == "https://maps.google.com/?cid=1")
    }

    @Test func emptyResponseHasNoPlaces() throws {
        let response = try GooglePlacesCoding.decoder.decode(SearchTextResponse.self, from: Data("{}".utf8))
        #expect(response.places == nil)
    }

    @Test func searchRequestEncodesRectangleAndOmitsOpenNowWhenOff() throws {
        let request = SearchTextRequest(
            textQuery: "Café",
            openNow: nil,
            locationRestriction: .init(rectangle: .init(
                low: GoogleLatLng(GeoPoint(latitude: 1, longitude: 2)),
                high: GoogleLatLng(GeoPoint(latitude: 3, longitude: 4))
            ))
        )
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(object["textQuery"] as? String == "Café")
        #expect(object["languageCode"] as? String == "de")
        #expect(object["pageSize"] as? Int == 20)
        #expect(object["openNow"] == nil)
        let rectangle = (object["locationRestriction"] as? [String: Any])?["rectangle"] as? [String: Any]
        #expect((rectangle?["low"] as? [String: Any])?["latitude"] as? Double == 1)
    }
}
