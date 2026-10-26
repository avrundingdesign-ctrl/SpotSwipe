import Foundation
import Testing
@testable import SpotSwipe

@MainActor
struct SwipeDeckViewModelTests {
    private let center = GeoPoint(latitude: 50.94, longitude: 6.95)

    private func request(cards: Int = 10, hideSaved: Bool = true, radius: Double = 2_000) -> SearchRequest {
        SearchRequest(query: "Café", center: center, centerName: "Köln", radius: radius, cardsPerRound: cards, onlyOpenNow: false, hideSaved: hideSaved)
    }

    private func makeModel(cards: Int = 10, hideSaved: Bool = true, library: FakeLibrary = FakeLibrary()) -> SwipeDeckViewModel {
        SwipeDeckViewModel(request: request(cards: cards, hideSaved: hideSaved), service: MockPlacesService(delay: .zero), library: library)
    }

    @Test func roundIsCappedAtCardsPerRound() async {
        let ten = makeModel(cards: 10)
        await ten.load()
        #expect(ten.phase == .swiping)
        #expect(ten.deck.count == 10)

        let five = makeModel(cards: 5)
        await five.load()
        #expect(five.deck.count == 5)
    }

    @Test func onlyPlacesInsideTheRadiusAreShown() async {
        let model = makeModel(cards: 50)
        await model.load()
        #expect(!model.deck.isEmpty)
        for place in model.deck {
            #expect(place.distance(from: center) <= 2_000)
        }
        // Die Beispieldaten legen absichtlich Orte außerhalb des Radius an.
        let all = MockPlacesService.makePlaces(query: PlaceSearchQuery(text: "Café", center: center, radius: 2_000, onlyOpenNow: false))
        #expect(model.deck.count < all.count)
    }

    @Test func likeSavesAndSkipDoesNot() async {
        let library = FakeLibrary()
        let model = makeModel(library: library)
        await model.load()
        let first = model.current!
        model.decide(.like)
        let second = model.current!
        model.decide(.skip)

        #expect(library.saved.keys.sorted() == [first.id])
        #expect(library.saved[first.id] == "Café")
        #expect(model.liked.map(\.id) == [first.id])
        #expect(model.current?.id != second.id)
        #expect(model.progressText == "3 / 10")
    }

    @Test func undoRevertsLikeAndShowsCardAgain() async {
        let library = FakeLibrary()
        let model = makeModel(library: library)
        await model.load()
        let first = model.current!
        model.decide(.like)
        model.undo()

        #expect(library.saved.isEmpty)
        #expect(model.liked.isEmpty)
        #expect(model.current?.id == first.id)
        #expect(!model.canUndo)
    }

    @Test func finishesAfterLastCardAndUndoReopens() async {
        let model = makeModel(cards: 5)
        await model.load()
        for _ in 0..<5 { model.decide(.skip) }
        #expect(model.phase == .finished)
        #expect(model.current == nil)

        model.undo()
        #expect(model.phase == .swiping)
        #expect(model.current != nil)
    }

    @Test func savedPlacesAreHiddenWhenSettingIsOn() async {
        let all = MockPlacesService.makePlaces(query: PlaceSearchQuery(text: "Café", center: center, radius: 2_000, onlyOpenNow: false))
        let library = FakeLibrary()
        library.saved[all[0].id] = "Café"

        let hiding = makeModel(hideSaved: true, library: library)
        await hiding.load()
        #expect(!hiding.deck.contains { $0.id == all[0].id })

        let showing = makeModel(hideSaved: false, library: library)
        await showing.load()
        #expect(showing.deck.contains { $0.id == all[0].id })
    }

    @Test func makeDeckRemovesDuplicates() {
        let place = Place(id: "a", name: "A", location: center)
        let deck = SwipeDeckViewModel.makeDeck(from: [place, place], center: center, radius: 100, excluding: [], limit: 10)
        #expect(deck.count == 1)
    }

    @Test func onlyFarAwayResultsEndInEmptyPhase() async {
        // ~5,5 km nördlich, Radius 2 km: Google liefert per Rechteck evtl. solche Treffer, wir filtern sie raus.
        let far = Place(id: "far", name: "Weit weg", location: GeoPoint(latitude: center.latitude + 0.05, longitude: center.longitude))
        let model = SwipeDeckViewModel(request: request(), service: StubPlacesService(places: [far]), library: FakeLibrary())
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func serviceErrorEndsInFailedPhase() async {
        let model = SwipeDeckViewModel(request: request(), service: StubPlacesService(error: PlacesError.http(status: 403, message: nil)), library: FakeLibrary())
        await model.load()
        #expect(model.phase == .failed(PlacesError.http(status: 403, message: nil).errorDescription!))
    }
}

final class StubPlacesService: PlacesService {
    let attribution = "Test"
    private let places: [Place]
    private let error: PlacesError?

    init(places: [Place] = [], error: PlacesError? = nil) {
        self.places = places
        self.error = error
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        if let error { throw error }
        return places
    }

    func placeDetails(id: String) async throws -> Place {
        guard let place = places.first(where: { $0.id == id }) else { throw PlacesError.decoding }
        return place
    }

    func photoData(for photo: PlacePhoto, maxWidth: Int) async throws -> Data { Data() }
}

final class FakeLibrary: PlaceLibrary {
    var saved: [String: String] = [:]

    func savedPlaceIDs() -> Set<String> { Set(saved.keys) }
    func save(_ place: Place, searchTerm: String) { saved[place.id] = searchTerm }
    func remove(placeID: String) { saved[placeID] = nil }
}
