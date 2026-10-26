import Foundation
import Testing
@testable import SpotSwipe

@MainActor
struct AISearchTests {
    private let center = GeoPoint(latitude: 50.94, longitude: 6.95)

    private var places: [Place] {
        ["a", "b", "c"].enumerated().map { index, id in
            Place(id: id, name: "Ort \(id)", category: "Café",
                  location: GeoPoint(latitude: center.latitude + Double(index) * 0.001, longitude: center.longitude))
        }
    }

    private func request(useAI: Bool) -> SearchRequest {
        SearchRequest(query: "ruhiges Café zum Arbeiten", center: center, centerName: "Köln", radius: 2_000,
                      cardsPerRound: 10, onlyOpenNow: false, hideSaved: false, useAI: useAI)
    }

    @Test func plannedTermsAreSearchedAndRankingOrdersTheDeck() async {
        let service = RecordingPlacesService(places: places)
        let assistant = StubAssistant(
            plan: AIQueryPlan(queries: ["Café", "Coworking Space"], criteria: "ruhig, WLAN"),
            picks: [AIPick(index: 2, reason: "Ruhig und mit großen Tischen."), AIPick(index: 0, reason: nil)]
        )
        let model = SwipeDeckViewModel(request: request(useAI: true), service: service, library: FakeLibrary(), assistant: assistant)
        await model.load()

        #expect(service.queries == ["Café", "Coworking Space"])
        #expect(model.deck.map(\.id) == ["c", "a"], "Nur die Auswahl der KI, in ihrer Reihenfolge")
        #expect(model.deck.first?.aiReason == "Ruhig und mit großen Tischen.")
        #expect(model.deck.last?.aiReason == nil)
        #expect(model.aiProvider == .claude)
        #expect(model.notice == nil)
        #expect(assistant.rankedCriteria == "ruhig, WLAN")
    }

    @Test func failingAIFallsBackToNormalSearch() async {
        let service = RecordingPlacesService(places: places)
        let model = SwipeDeckViewModel(request: request(useAI: true), service: service, library: FakeLibrary(),
                                       assistant: StubAssistant(plan: nil, picks: nil))
        await model.load()

        #expect(service.queries == ["ruhiges Café zum Arbeiten"])
        #expect(model.deck.map(\.id) == ["a", "b", "c"])
        #expect(model.aiProvider == nil)
        #expect(model.notice != nil)
        #expect(model.phase == .swiping)
    }

    @Test func aiOffNeverAsksTheAssistant() async {
        let assistant = StubAssistant(plan: AIQueryPlan(queries: ["X"], criteria: ""), picks: [])
        let model = SwipeDeckViewModel(request: request(useAI: false), service: RecordingPlacesService(places: places),
                                       library: FakeLibrary(), assistant: assistant)
        await model.load()
        #expect(assistant.calls == 0)
        #expect(model.deck.count == 3)
    }

    @Test func rankReplyMapsIdsAndDropsUnknownOnes() throws {
        let json = #"{"picks":[{"id":"p1","reason":"Gut"},{"id":"p7","reason":"erfunden"},{"id":"p1","reason":"doppelt"},{"id":"x2","reason":""},{"id":"p0","reason":"  "}]}"#
        let reply = try JSONDecoder().decode(SpotRankReply.self, from: Data(json.utf8))
        let picks = reply.picks(candidateCount: 3)
        #expect(picks == [AIPick(index: 1, reason: "Gut"), AIPick(index: 0, reason: nil)])
    }

    @Test func fallbackTermsSplitSentencesIntoWords() {
        #expect(SwipeDeckViewModel.fallbackTerms(for: "ruhiges Café zum Arbeiten") == ["ruhiges", "Café", "zum", "Arbeiten"])
        #expect(SwipeDeckViewModel.fallbackTerms(for: "Bar am Rhein, Bar") == ["Bar", "Rhein"])
        #expect(SwipeDeckViewModel.fallbackTerms(for: "Café").isEmpty, "Ein Wort wurde schon gesucht")
    }

    @Test func sentenceWithoutResultsFallsBackToWords() async {
        let service = WordOnlyPlacesService(places: places, word: "Café")
        let model = SwipeDeckViewModel(request: request(useAI: false), service: service, library: FakeLibrary())
        await model.load()
        #expect(model.deck.count == 3)
        #expect(service.queries.first == "ruhiges Café zum Arbeiten")
        #expect(service.queries.contains("Café"))
    }

    @Test func queryReplyKeepsAtMostThreeTerms() {
        let plan = SpotQueryReply(queries: [" ", "Café", "Bar", "Park", "Zoo"], criteria: "ruhig").plan
        #expect(plan == AIQueryPlan(queries: ["Café", "Bar", "Park"], criteria: "ruhig"))
        #expect(SpotQueryReply(queries: [" "], criteria: "").plan == nil)
    }
}

final class RecordingPlacesService: PlacesService {
    let attribution = "Test"
    private let places: [Place]
    private(set) var queries: [String] = []

    init(places: [Place]) {
        self.places = places
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        queries.append(query.text)
        return places
    }

    func extras(for place: Place) async -> PlaceExtras? { nil }
    func consumeNotice() async -> String? { nil }
    func photoData(for photo: PlacePhoto) async throws -> Data { Data() }
}

final class StubAssistant: SearchAssistant {
    private(set) var lastProvider: AIProvider?
    private(set) var calls = 0
    private(set) var rankedCriteria: String?
    private let stubPlan: AIQueryPlan?
    private let stubPicks: [AIPick]?

    init(plan: AIQueryPlan?, picks: [AIPick]?) {
        stubPlan = plan
        stubPicks = picks
    }

    func plan(for wish: String) async -> AIQueryPlan? {
        calls += 1
        if stubPlan != nil { lastProvider = .claude }
        return stubPlan
    }

    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]? {
        calls += 1
        rankedCriteria = plan.criteria
        if stubPicks != nil { lastProvider = .claude }
        return stubPicks
    }
}

/// Findet nur zu genau einem Wort etwas – wie Apple Karten bei ganzen Sätzen.
final class WordOnlyPlacesService: PlacesService {
    let attribution = "Test"
    private let places: [Place]
    private let word: String
    private(set) var queries: [String] = []

    init(places: [Place], word: String) {
        self.places = places
        self.word = word
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        queries.append(query.text)
        return query.text == word ? places : []
    }

    func extras(for place: Place) async -> PlaceExtras? { nil }
    func consumeNotice() async -> String? { nil }
    func photoData(for photo: PlacePhoto) async throws -> Data { Data() }
}
