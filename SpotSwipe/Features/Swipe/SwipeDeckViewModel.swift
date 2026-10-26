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
        let ai = request.useAI ? assistant : nil
        do {
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
                if let picks = await ai.rank(request.query, plan: plan ?? fallbackPlan, candidates: pool, limit: request.cardsPerRound + 5),
                   !picks.isEmpty {
                    candidates = Self.ordered(pool, by: picks, fillingUpTo: request.cardsPerRound)
                    aiProvider = ai.lastProvider
                } else {
                    notice = String(localized: "KI gerade nicht erreichbar – normale Suche.")
                }
            } else if ai != nil, plan == nil {
                notice = String(localized: "KI gerade nicht erreichbar – normale Suche.")
            }

            deck = Array(candidates.prefix(request.cardsPerRound))
            reserve = Array(candidates.dropFirst(request.cardsPerRound))
            position = 0
            liked = []
            history = []
            requestedExtras = []
            phase = deck.isEmpty ? .empty : .swiping
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "Die Suche hat nicht geklappt.")
        }
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

    /// Neue Suche mit „auch geschlossene Orte“, wenn die Runde leer blieb.
    func retryIncludingClosed() async {
        request.onlyOpenNow = false
        await load()
        await enrichUpcoming()
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

    /// Ordnet die Kandidaten wie von der KI gewählt und hängt die Begründungen an.
    /// Wählt die KI weniger Orte als eine Runde braucht, rücken die übrigen Treffer
    /// (ohne Begründung, in der Reihenfolge von Apple Karten) dahinter auf.
    nonisolated static func ordered(_ candidates: [Place], by picks: [AIPick], fillingUpTo minimum: Int = 0) -> [Place] {
        var chosen = Set<Int>()
        var result: [Place] = picks.compactMap { pick in
            guard candidates.indices.contains(pick.index), chosen.insert(pick.index).inserted else { return nil }
            var place = candidates[pick.index]
            place.aiReason = pick.reason
            return place
        }
        for index in candidates.indices where result.count < minimum && !chosen.contains(index) {
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
