import Foundation

nonisolated struct PlaceSearchQuery: Hashable, Sendable {
    var text: String
    var center: GeoPoint
    var radius: Double
    var onlyOpenNow: Bool
}

/// Quelle für Orte und Fotos. Produktiv Google Places, in Tests und ohne Key Beispieldaten.
protocol PlacesService: AnyObject {
    /// Wird unter den Karten angezeigt (Pflicht-Attribution bei Google).
    var attribution: String { get }
    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place]
    func placeDetails(id: String) async throws -> Place
    func photoData(for photo: PlacePhoto, maxWidth: Int) async throws -> Data
}

nonisolated enum PlacesError: LocalizedError, Equatable {
    case invalidResponse
    case http(status: Int, message: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Keine gültige Antwort vom Server."
        case .http(let status, let message):
            switch status {
            case 401, 403: "Der Google-API-Key wurde abgelehnt. Prüfe Key und Beschränkungen."
            case 429: "Zu viele Anfragen. Versuch es gleich noch einmal."
            default: message ?? "Serverfehler (\(status))."
            }
        case .decoding:
            "Die Antwort von Google konnte nicht gelesen werden."
        }
    }
}
