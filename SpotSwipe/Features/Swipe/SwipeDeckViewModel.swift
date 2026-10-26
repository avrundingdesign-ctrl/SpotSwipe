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

    private(set) var request: SearchRequest
    private(set) var phase: Phase = .loading
    private(set) var deck: [Place] = []
    /// Index der obersten Karte im Deck.
    private(set) var position = 0
    private(set) var liked: [Place] = []
    /// Hinweis vom Proxy (Tageslimit, nicht erreichbar …), ersetzt die Quellenzeile.
    private(set) var notice: String?

    /// Nachrücker für Orte, die sich beim Ergänzen als geschlossen herausstellen.
    @ObservationIgnored private var reserve: [Place] = []
    @ObservationIgnored private var requestedExtras: Set<String> = []
    @ObservationIgnored private var history: [(place: Place, decision: Decision)] = []
    @ObservationIgnored private let service: any PlacesService
    @ObservationIgnored private let library: any PlaceLibrary

    init(request: SearchRequest, service: any PlacesService, library: any PlaceLibrary) {
        self.request = request
        self.service = service
        self.library = library
    }

    var remaining: ArraySlice<Place> { deck[min(position, deck.count)...] }
    var current: Place? { remaining.first }
    var canUndo: Bool { !history.isEmpty }
    var progressText: String { "\(min(position + 1, deck.count)) / \(deck.count)" }

    func load() async {
        phase = .loading
        do {
            let results = try await service.searchPlaces(PlaceSearchQuery(
                text: request.query,
                center: request.center,
                radius: request.radius
            ))
            let candidates = Self.candidates(
                from: results,
                center: request.center,
                radius: request.radius,
                excluding: request.hideSaved ? library.savedPlaceIDs() : []
            )
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
