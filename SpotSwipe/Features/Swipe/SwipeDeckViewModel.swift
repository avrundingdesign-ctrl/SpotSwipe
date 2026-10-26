import Foundation
import Observation

/// Eine Swipe-Runde: Orte laden, nach und nach mit Fotos ergänzen, merken/überspringen, rückgängig machen.
/// Pro Suche gibt es genau eine Runde mit höchstens 5 bzw. 10 Karten (Einstellung).
@Observable
final class SwipeDeckViewModel {
    enum Phase: Equatable {
        case loading, swiping, finished, empty
        case failed(String)
    }

    enum Decision {
        case like, skip
    }

    /// Was beim Laden gerade passiert – bei KI-Suche dauert es länger, deshalb sichtbar.
    enum LoadingStep {
        case understanding, searching, ranking
    }

    private(set) var request: SearchRequest
    private(set) var phase: Phase = .loading
    private(set) var deck: [Place] = []
    /// Index der obersten Karte im Deck.
    private(set) var position = 0
    private(set) var liked: [Place] = []
    /// Hinweis vom Proxy (Tageslimit, nicht erreichbar …), ersetzt die Quellenzeile.
    private(set) var notice: String?
    private(set) var loadingStep: LoadingStep = .searching
    /// Wer die Treffer sortiert hat, falls die KI-Suche geklappt hat.
    private(set) var aiProvider: AIProvider?
    /// Was „Nur geöffnete Orte“ in dieser Runde aussortiert hat – samt Fotos, für „Auch geschlossene zeigen“.
    private(set) var closedPlaces: [Place] = []

    /// Nachrücker für Orte, die sich beim Ergänzen als geschlossen herausstellen.
    @ObservationIgnored private var reserve: [Place] = []
    @ObservationIgnored private var requestedExtras: Set<String> = []
    @ObservationIgnored private var history: [(place: Place, decision: Decision)] = []
    @ObservationIgnored private let service: any PlacesService
    @ObservationIgnored private let library: any PlaceLibrary
    @ObservationIgnored private let assistant: (any SearchAssistant)?

    /// Höchstens so viele Orte gehen zur KI – mehr bringt kaum bessere Treffer, kostet aber Zeit.
    static let maxAICandidates = 25

    init(request: SearchRequest, service: any PlacesService, library: any PlaceLibrary, assistant: (any SearchAssistant)? = nil) {
        self.request = request
        self.service = service
        self.library = library
        self.assistant = assistant
    }

    var remaining: ArraySlice<Place> { deck[min(position, deck.count)...] }
    var current: Place? { remaining.first }
    var canUndo: Bool { !history.isEmpty }
    var progressText: String { "\(min(position + 1, deck.count)) / \(deck.count)" }

    func load() async {
        phase = .loading
        notice = nil
        aiProvider = nil
        closedPlaces = []
        var ai = request.useAI ? assistant : nil
        do {
            // Normalfall mit Claude: Claude nennt die Orte selbst, Apple Karten liefert nur Lage und Adresse.
            // Apple Karten weiß nicht, welches Café ruhig ist – Claude schon.
            if let assistant = ai {
                loadingStep = .understanding
                let limit = min(Self.maxRecommendations, request.cardsPerRound * 2)
                if let picks = await assistant.recommend(request.query, near: request.center, radius: request.radius, limit: limit) {
                    loadingStep = .searching
                    let found = await resolveRecommendations(picks)
                    debugLog("Empfehlungen: \(picks.compactMap(\.name)) → gefunden: \(found.values.map(\.name))")
                    let places = Self.ordered([], by: picks, suggested: found)
                    if !places.isEmpty {
                        aiProvider = assistant.lastProvider
                        start(with: places)
                        return
                    }
                    // Claude kennt hier nichts Passendes: normale Suche ohne KI.
                    notice = String(localized: "Claude kennt hier keine passenden Orte – normale Suche.")
                    ai = nil
                }
            }

            var plan: AIQueryPlan?
            if let ai {
                loadingStep = .understanding
                plan = await ai.plan(for: request.query)
                debugLog("Plan: \(plan.map { "\($0.queries) / \($0.criteria)" } ?? "keiner") von \(ai.lastProvider?.label ?? "-")")
            }

            loadingStep = .searching
            var results: [Place] = []
            var lastError: (any Error)?
            for term in plan?.queries ?? [request.query] {
                do {
                    results += try await service.searchPlaces(PlaceSearchQuery(text: term, center: request.center, radius: request.radius))
                } catch {
                    lastError = error
                }
            }
            if results.isEmpty, let lastError { throw lastError }
            if results.isEmpty {
                // Apple Karten versteht keine ganzen Sätze. Ohne Treffer: einzelne Wörter versuchen
                // („ruhiges Café zum Arbeiten“ → „Café“).
                for word in Self.fallbackTerms(for: request.query) {
                    results += (try? await service.searchPlaces(PlaceSearchQuery(text: word, center: request.center, radius: request.radius))) ?? []
                }
            }
            debugLog("Apple Karten: \(results.count) Treffer für \(plan?.queries ?? [request.query])")

            var candidates = Self.candidates(
                from: results,
                center: request.center,
                radius: request.radius,
                excluding: request.hideSaved ? library.savedPlaceIDs() : []
            )

            if let ai, !candidates.isEmpty {
                loadingStep = .ranking
                let pool = Array(candidates.prefix(Self.maxAICandidates))
                let fallbackPlan = AIQueryPlan(queries: [request.query], criteria: "")
                // Mit „Nur geöffnete Orte“ fliegen geschlossene Karten raus – dann alle passenden
                // Orte holen, damit genug nachrücken (abends sind z. B. viele Cafés schon zu).
                let limit = request.onlyOpenNow ? pool.count : request.cardsPerRound + 5
                if let picks = await ai.rank(request.query, plan: plan ?? fallbackPlan, candidates: pool, limit: limit),
                   !picks.isEmpty {
                    candidates = Self.ordered(pool, by: picks, fillingUpTo: request.cardsPerRound)
                    aiProvider = ai.lastProvider
                } else {
                    notice = String(localized: "KI gerade nicht erreichbar – normale Suche.")
                }
            } else if ai != nil, plan == nil {
                notice = String(localized: "KI gerade nicht erreichbar – normale Suche.")
            }

            start(with: candidates)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "Die Suche hat nicht geklappt.")
        }
    }

    /// Neue Runde: die ersten Orte als Karten, der Rest als Nachrücker.
    private func start(with candidates: [Place]) {
        deck = Array(candidates.prefix(request.cardsPerRound))
        reserve = Array(candidates.dropFirst(request.cardsPerRound))
        position = 0
        liked = []
        history = []
        requestedExtras = []
        phase = deck.isEmpty ? .empty : .swiping
    }

    /// Ergänzt Fotos, Bewertung und Öffnungsstatus der Reihe nach, oberste Karte zuerst.
    /// Läuft, bis alle noch offenen Karten versorgt sind; neue Nachrücker werden mit erfasst.
    func enrichUpcoming() async {
        while !Task.isCancelled {
            guard let index = deck.indices.first(where: { $0 >= position && !requestedExtras.contains(deck[$0].id) }) else {
                return
            }
            let place = deck[index]
            requestedExtras.insert(place.id)
            let extras = await service.extras(for: place)
            if let message = await service.consumeNotice() { notice = message }
            guard let extras else { continue }
            apply(extras, to: place.id)
        }
    }

    /// „Auch geschlossene Orte zeigen“: die aussortierten Orte als eigene Runde, ohne neue Suche.
    /// Blieb die Suche von Anfang an leer, wird ohne den Filter neu gesucht.
    func retryIncludingClosed() async {
        request.onlyOpenNow = false
        guard !closedPlaces.isEmpty else {
            await load()
            await enrichUpcoming()
            return
        }
        deck = Array(closedPlaces.prefix(request.cardsPerRound))
        closedPlaces = []
        reserve = []
        position = 0
        liked = []
        history = []
        phase = .swiping
    }

    func decide(_ decision: Decision) {
        guard let place = current else { return }
        history.append((place, decision))
        if decision == .like {
            liked.append(place)
            library.save(place, searchTerm: request.query)
        }
        position += 1
        if position >= deck.count { phase = .finished }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        if last.decision == .like {
            liked.removeAll { $0.id == last.place.id }
            library.remove(placeID: last.place.id)
        }
        position = max(0, position - 1)
        phase = .swiping
    }

    private func apply(_ extras: PlaceExtras, to id: String) {
        guard let index = deck.firstIndex(where: { $0.id == id }) else { return }
        let merged = deck[index].merging(extras)

        if request.onlyOpenNow, merged.isOpenNow == false, index >= position {
            deck.remove(at: index)
            closedPlaces.append(merged)
            if !reserve.isEmpty { deck.append(reserve.removeFirst()) }
            if position >= deck.count {
                phase = history.isEmpty ? .empty : .finished
            }
            return
        }

        deck[index] = merged
        // Schon gemerkt, bevor die Fotos da waren? Dann den Schnappschuss nachziehen.
        if let likedIndex = liked.firstIndex(where: { $0.id == id }) {
            liked[likedIndex] = merged
            library.save(merged, searchTerm: request.query)
        }
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[KI-Suche] \(message())")
        #endif
    }

    /// Einzelwörter als Ersatz-Suchbegriffe: mindestens drei Buchstaben („Bar“), höchstens vier Wörter, ohne Dubletten.
    /// Ein einzelnes Wort ergibt keinen Ersatz – dafür wurde schon gesucht.
    nonisolated static func fallbackTerms(for query: String) -> [String] {
        let words = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard words.count > 1 else { return [] }
        var seen = Set<String>()
        return Array(words.filter { $0.count >= 3 && seen.insert($0.lowercased()).inserted }.prefix(4))
    }

    /// So viele Orte nennt Claude höchstens – etwa jeder zweite findet sich in Apple Karten im Umkreis.
    static let maxRecommendations = 20

    /// Sucht die von der KI genannten Orte in Apple Karten, alle gleichzeitig. Nur echte Treffer mit
    /// passendem Namen im Umkreis zählen – so fallen erfundene oder zu weit entfernte Orte heraus.
    private func resolveRecommendations(_ picks: [AIPick]) async -> [String: Place] {
        let names = Array(picks.compactMap(\.name).prefix(Self.maxRecommendations))
        // Alle Suchen starten sofort; sie laufen gleichzeitig, weil jede beim Warten auf Apple Karten pausiert.
        let searches = names.map { name in
            let query = PlaceSearchQuery(text: name, center: request.center, radius: request.radius)
            return Task { (try? await service.searchPlaces(query)) ?? [] }
        }
        var results: [[Place]] = []
        for search in searches { results.append(await search.value) }

        let excluded = request.hideSaved ? library.savedPlaceIDs() : []
        var found: [String: Place] = [:]
        var taken = Set<String>()
        for (name, places) in zip(names, results) {
            let match = Self.candidates(from: places, center: request.center, radius: request.radius, excluding: excluded)
                .first { Self.namesMatch($0.name, name) && !taken.contains($0.id) }
            if let match {
                found[name] = match
                taken.insert(match.id)
            }
        }
        return found
    }

    /// Passt der Name aus Apple Karten zum genannten? Verglichen wird Wort für Wort ab dem Anfang, ohne
    /// Allerweltswörter davor: „Le Lion · Bar de Paris“ passt zu „Le Lion“, „Knuth“ zu „Café Knuth“,
    /// „Clockers“ zu „Clockers Bar“ – aber nicht „Green Lion Computer“ zu „Le Lion“.
    nonisolated static func namesMatch(_ found: String, _ wanted: String) -> Bool {
        let generic: Set<String> = ["cafe", "bar", "restaurant", "the", "das", "der", "die", "le", "la", "il", "el",
                                    "coffee", "kaffee", "bistro", "pizzeria", "und", "and"]
        func words(_ text: String) -> [String] {
            let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            let all = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            return Array(all.drop { generic.contains($0) })
        }
        let a = words(found), b = words(wanted)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.starts(with: b) || b.starts(with: a)
    }

    /// Ordnet die Kandidaten wie von der KI gewählt und hängt die Begründungen an. Vorschläge der KI
    /// stehen an ihrer Stelle, sofern Apple Karten sie gefunden hat (`suggested`, nach Name).
    /// Wählt die KI weniger Orte als eine Runde braucht, rücken die übrigen Treffer
    /// (ohne Begründung, in der Reihenfolge von Apple Karten) dahinter auf.
    nonisolated static func ordered(_ candidates: [Place], by picks: [AIPick], suggested: [String: Place] = [:],
                                    fillingUpTo minimum: Int = 0) -> [Place] {
        var chosen = Set<Int>()
        var chosenIDs = Set<String>()
        var result: [Place] = picks.compactMap { pick in
            var place: Place
            if let index = pick.index {
                guard candidates.indices.contains(index), chosen.insert(index).inserted else { return nil }
                place = candidates[index]
            } else if let name = pick.name, let match = suggested[name] {
                place = match
            } else {
                return nil
            }
            guard chosenIDs.insert(place.id).inserted else { return nil }
            place.aiReason = pick.reason
            return place
        }
        for index in candidates.indices where result.count < minimum && !chosen.contains(index) && !chosenIDs.contains(candidates[index].id) {
            result.append(candidates[index])
        }
        return result
    }

    /// Doppelte und schon gemerkte Orte raus, nur echter Umkreis.
    nonisolated static func candidates(
        from places: [Place],
        center: GeoPoint,
        radius: Double,
        excluding excluded: Set<String>
    ) -> [Place] {
        var seen = Set<String>()
        return places.filter { place in
            guard !excluded.contains(place.id), seen.insert(place.id).inserted else { return false }
            return GeoMath.distance(from: center, to: place.location) <= radius
        }
    }
}
