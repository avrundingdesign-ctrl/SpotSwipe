import Foundation
import Testing
@testable import SpotSwipe

@MainActor
struct SwipeDeckViewModelTests {
    private let center = GeoPoint(latitude: 50.94, longitude: 6.95)

    private func request(cards: Int = 10, hideSaved: Bool = true, onlyOpen: Bool = false, radius: Double = 2_000) -> SearchRequest {
        SearchRequest(query: "Café", center: center, centerName: "Köln", radius: radius, cardsPerRound: cards, onlyOpenNow: onlyOpen, hideSaved: hideSaved)
    }

    private func makeModel(cards: Int = 10, hideSaved: Bool = true, onlyOpen: Bool = false, library: FakeLibrary = FakeLibrary()) -> SwipeDeckViewModel {
        SwipeDeckViewModel(request: request(cards: cards, hideSaved: hideSaved, onlyOpen: onlyOpen), service: MockPlacesService(delay: .zero), library: library)
    }

    private var allMockPlaces: [Place] {
        MockPlacesService.makePlaces(query: PlaceSearchQuery(text: "Café", center: center, radius: 2_000))
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
        #expect(model.deck.count < allMockPlaces.count)
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
        #expect(library.saved[first.id]?.term == "Café")
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
        let library = FakeLibrary()
        library.saved[allMockPlaces[0].id] = (term: "Café", place: allMockPlaces[0])

        let hiding = makeModel(hideSaved: true, library: library)
        await hiding.load()
        #expect(!hiding.deck.contains { $0.id == allMockPlaces[0].id })

        let showing = makeModel(hideSaved: false, library: library)
        await showing.load()
        #expect(showing.deck.contains { $0.id == allMockPlaces[0].id })
    }

    @Test func candidatesRemoveDuplicates() {
        let place = Place(id: "a", name: "A", location: center)
        let candidates = SwipeDeckViewModel.candidates(from: [place, place], center: center, radius: 100, excluding: [])
        #expect(candidates.count == 1)
    }

    @Test func onlyFarAwayResultsEndInEmptyPhase() async {
        // ~5,5 km nördlich bei 2 km Radius: wird herausgefiltert.
        let far = Place(id: "far", name: "Weit weg", location: GeoPoint(latitude: center.latitude + 0.05, longitude: center.longitude))
        let model = SwipeDeckViewModel(request: request(), service: StubPlacesService(places: [far]), library: FakeLibrary())
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func searchErrorEndsInFailedPhase() async {
        let model = SwipeDeckViewModel(request: request(), service: StubPlacesService(error: .searchFailed), library: FakeLibrary())
        await model.load()
        #expect(model.phase == .failed(PlacesError.searchFailed.errorDescription!))
    }

    // MARK: - Ergänzen über den Proxy

    @Test func enrichmentAddsPhotosAndRating() async {
        let model = makeModel(cards: 5)
        await model.load()
        #expect(model.deck.allSatisfy { $0.photos.isEmpty && $0.rating == nil })

        await model.enrichUpcoming()
        #expect(model.deck.allSatisfy { !$0.photos.isEmpty && $0.rating != nil })
    }

    @Test func closedPlacesAreReplacedWhenOnlyOpenIsOn() async {
        let model = makeModel(cards: 5, onlyOpen: true)
        await model.load()
        // Ort Nr. 3 hat in den Beispieldaten geschlossen.
        #expect(model.deck.contains { $0.id.hasPrefix("mock-3-") })

        await model.enrichUpcoming()
        #expect(!model.deck.contains { $0.id.hasPrefix("mock-3-") })
        #expect(model.deck.count == 5, "Ein Nachrücker aus der Reserve füllt die Lücke")
        #expect(model.deck.allSatisfy { $0.isOpenNow == true })
    }

    @Test func closedPlacesStayWhenOnlyOpenIsOff() async {
        let model = makeModel(cards: 5, onlyOpen: false)
        await model.load()
        await model.enrichUpcoming()
        #expect(model.deck.contains { $0.isOpenNow == false })
    }

    @Test func likeBeforePhotosArriveUpdatesLibraryLater() async {
        let library = FakeLibrary()
        let model = SwipeDeckViewModel(request: request(), service: MockPlacesService(delay: .milliseconds(40)), library: library)
        await model.load()
        let first = model.current!

        let enrichment = Task { await model.enrichUpcoming() }
        await Task.yield() // Anfrage für die oberste Karte läuft jetzt
        model.decide(.like) // gemerkt, bevor die Fotos da sind
        #expect(library.saved[first.id]?.place.photos.isEmpty == true)

        await enrichment.value
        #expect(library.saved[first.id]?.place.photos.isEmpty == false)
    }

    @Test func proxyNoticeIsShown() async {
        let stub = StubPlacesService(places: [Place(id: "a", name: "A", location: center)], notice: "Tageslimit erreicht")
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary())
        await model.load()
        await model.enrichUpcoming()
        #expect(model.notice == "Tageslimit erreicht")
    }
}

final class FakeLibrary: PlaceLibrary {
    var saved: [String: (term: String, place: Place)] = [:]

    func savedPlaceIDs() -> Set<String> { Set(saved.keys) }
    func save(_ place: Place, searchTerm: String) { saved[place.id] = (searchTerm, place) }
    func remove(placeID: String) { saved[placeID] = nil }
}

final class StubPlacesService: PlacesService {
    let attribution = "Test"
    private let places: [Place]
    private let error: PlacesError?
    private var notice: String?

    init(places: [Place] = [], error: PlacesError? = nil, notice: String? = nil) {
        self.places = places
        self.error = error
        self.notice = notice
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        if let error { throw error }
        return places
    }

    func extras(for place: Place) async -> PlaceExtras? { nil }

    func consumeNotice() async -> String? {
        defer { notice = nil }
        return notice
    }

    func photoData(for photo: PlacePhoto) async throws -> Data { Data() }
}
