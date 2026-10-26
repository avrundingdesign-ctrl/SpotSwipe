import Foundation
import Observation

/// Eine Swipe-Runde: Orte laden, merken/überspringen, rückgängig machen.
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
                radius: request.radius,
                onlyOpenNow: request.onlyOpenNow
            ))
            deck = Self.makeDeck(
                from: results,
                center: request.center,
                radius: request.radius,
                excluding: request.hideSaved ? library.savedPlaceIDs() : [],
                limit: request.cardsPerRound
            )
            position = 0
            liked = []
            history = []
            phase = deck.isEmpty ? .empty : .swiping
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "Die Suche hat nicht geklappt.")
        }
    }

    /// Neue Suche mit „auch geschlossene Orte“, wenn die Runde leer blieb.
    func retryIncludingClosed() async {
        request.onlyOpenNow = false
        await load()
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

    /// Doppelte und schon gemerkte Orte raus, nur echter Umkreis (Google liefert ein Rechteck), dann kürzen.
    nonisolated static func makeDeck(
        from places: [Place],
        center: GeoPoint,
        radius: Double,
        excluding excluded: Set<String>,
        limit: Int
    ) -> [Place] {
        var seen = Set<String>()
        let filtered = places.filter { place in
            guard !excluded.contains(place.id), seen.insert(place.id).inserted else { return false }
            return GeoMath.distance(from: center, to: place.location) <= radius
        }
        return Array(filtered.prefix(limit))
    }
}
