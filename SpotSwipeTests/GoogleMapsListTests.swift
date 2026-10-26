import Foundation
import Testing
@testable import SpotSwipe

struct GoogleMapsListTests {
    @Test func shortlistURLListsThePlaceIDs() {
        let url = GoogleMapsList.shortlistURL(placeIDs: ["ChIJa", "", "ChIJb"])
        #expect(url?.absoluteString == "https://www.google.com/maps/@?api=1&map_action=shortlist&place_ids=ChIJa,ChIJb")
    }

    @Test func shortlistTakesAtMostTwentyPlaces() throws {
        let ids = (0..<25).map { "id\($0)" }
        let url = try #require(GoogleMapsList.shortlistURL(placeIDs: ids))
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "place_ids" }?.value
        #expect(value?.split(separator: ",").count == GoogleMapsList.maxPlaces)
    }

    @Test func noIDsMeansNoLink() {
        #expect(GoogleMapsList.shortlistURL(placeIDs: []) == nil)
        #expect(GoogleMapsList.shortlistURL(placeIDs: ["", ""]) == nil)
    }

    @Test func placeIDsReplyKeepsEmptyIDsInPlace() throws {
        let reply = try JSONDecoder().decode(ProxyPlaceIDsReply.self, from: Data(#"{"ids":["ChIJa",""]}"#.utf8))
        #expect(reply.ids == ["ChIJa", ""])
    }
}
