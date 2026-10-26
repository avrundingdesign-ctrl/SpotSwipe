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

    @Test func topCardArrivesWithPhotosAndTheRestFollows() async {
        let model = makeModel(cards: 5)
        await model.load()
        #expect(model.current?.photos.isEmpty == false, "Die oberste Karte kommt schon mit Fotos")
        #expect(model.deck.contains { $0.rating == nil }, "Der Rest folgt erst beim Wischen")

        await model.enrichUpcoming()
        #expect(model.deck.allSatisfy { $0.rating != nil })
        // Ort Nr. 0 hat in den Beispieldaten keine Fotos – er steht jetzt hinten statt vorne.
        #expect(model.deck.last?.id.hasPrefix("mock-0-") == true)
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

    @Test func closedPlacesCanBeShownAfterTheRound() async {
        let model = makeModel(cards: 5, onlyOpen: true)
        await model.load()
        await model.enrichUpcoming()
        let closed = model.closedPlaces
        #expect(closed.contains { $0.id.hasPrefix("mock-3-") })

        while model.current != nil { model.decide(.skip) }
        #expect(model.phase == .finished)

        await model.retryIncludingClosed()
        #expect(model.phase == .swiping)
        #expect(model.deck.map(\.id) == closed.map(\.id))
        #expect(model.deck.allSatisfy { !$0.photos.isEmpty }, "Fotos sind schon da – keine neue Suche")
        #expect(model.closedPlaces.isEmpty)
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
        // Die beiden vorgeladenen Karten überspringen – erst die dritte hat noch keine Fotos.
        model.decide(.skip)
        model.decide(.skip)
        let third = model.current!
        #expect(third.photos.isEmpty)

        let enrichment = Task { await model.enrichUpcoming() }
        await Task.yield() // Anfrage für die oberste Karte läuft jetzt
        model.decide(.like) // gemerkt, bevor die Fotos da sind
        #expect(library.saved[third.id]?.place.photos.isEmpty == true)

        await enrichment.value
        #expect(library.saved[third.id]?.place.photos.isEmpty == false)
    }

    // MARK: - Fotos vor dem Deck

    private func places(_ ids: String...) -> [Place] {
        ids.map { Place(id: $0, name: $0.uppercased(), location: center) }
    }

    @Test func firstCardWithoutPhotosMovesToTheBack() async {
        let stub = PhotoStubPlacesService(places: places("a", "b", "c", "d"), withoutPhotos: ["a"])
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary())
        await model.load()
        #expect(model.phase == .swiping)
        #expect(model.deck.map(\.id) == ["b", "c", "d", "a"])
        #expect(model.current?.photos.isEmpty == false)
    }

    @Test func orderStaysWhenGoogleHasNoPhotosAtAll() async {
        let stub = PhotoStubPlacesService(places: places("a", "b", "c"), withoutPhotos: ["a", "b", "c"])
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary())
        await model.load()
        await model.enrichUpcoming()
        #expect(model.phase == .swiping)
        #expect(model.deck.map(\.id) == ["a", "b", "c"], "Ohne ein einziges Foto bleibt die Reihenfolge der Suche")
    }

    @Test func slowPhotosDoNotHoldTheDeckBack() async {
        let stub = PhotoStubPlacesService(places: places("a", "b"), delay: .seconds(2))
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary(), preloadBudget: .milliseconds(100))
        let started = ContinuousClock.now
        await model.load()
        #expect(ContinuousClock.now - started < .seconds(1))
        #expect(model.phase == .swiping)
    }

    @Test func cardWithoutPhotosMovesBackWhileSwipingButDrawnCardsStay() async {
        let stub = PhotoStubPlacesService(places: places("a", "b", "c", "d", "e", "f"), withoutPhotos: ["c", "e"])
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary())
        await model.load()
        #expect(model.deck.map(\.id) == ["a", "b", "c", "d", "e", "f"], "Vorgeladen wurden nur a und b")

        model.decide(.skip) // oben liegt jetzt b, dahinter schon sichtbar c
        await model.enrichUpcoming()
        // c ist bereits gezeichnet und bleibt stehen; e rutscht hinter f.
        #expect(model.deck.map(\.id) == ["a", "b", "c", "d", "f", "e"])
    }

    @Test func proxyNoticeIsShown() async {
        let stub = StubPlacesService(places: [Place(id: "a", name: "A", location: center)], notice: "Tageslimit erreicht")
        let model = SwipeDeckViewModel(request: request(), service: stub, library: FakeLibrary())
        await model.load()
        await model.enrichUpcoming()
        #expect(model.notice == "Tageslimit erreicht")
    }
}

/// Liefert zu jedem Ort Fotos – außer zu denen in `withoutPhotos` –, auf Wunsch verzögert.
final class PhotoStubPlacesService: PlacesService {
    let attribution = "Test"
    private let places: [Place]
    private let withoutPhotos: Set<String>
    private let delay: Duration

    init(places: [Place], withoutPhotos: Set<String> = [], delay: Duration = .zero) {
        self.places = places
        self.withoutPhotos = withoutPhotos
        self.delay = delay
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] { places }

    func extras(for place: Place) async -> PlaceExtras? {
        if delay > .zero { try? await Task.sleep(for: delay) }
        let photos = withoutPhotos.contains(place.id) ? [] : [PlacePhoto(url: URL(string: "mock://photo/\(place.id)/0")!)]
        return PlaceExtras(rating: 4.5, ratingCount: 12, photos: photos)
    }

    func consumeNotice() async -> String? { nil }

    func photoData(for photo: PlacePhoto) async throws -> Data { Data() }
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
