import Foundation

nonisolated struct PlaceSearchQuery: Hashable, Sendable {
    var text: String
    var center: GeoPoint
    var radius: Double
}

/// Quelle für Orte und Fotos. Produktiv Apple Karten plus Proxy, in Tests und Screenshots Beispieldaten.
protocol PlacesService: AnyObject {
    /// Steht unter den Karten (Quellenangabe; Google verlangt sie für Fotos und Bewertungen).
    var attribution: String { get }

    /// Grunddaten der Orte im Umkreis. Ohne Fotos und Bewertungen.
    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place]

    /// Bewertung, Fotos und Öffnungszeiten. `nil`, wenn nichts zu bekommen ist
    /// (Ort unbekannt, Simulator ohne App Attest, Tageslimit, offline).
    func extras(for place: Place) async -> PlaceExtras?

    /// Hinweis für die Oberfläche, falls zuletzt etwas nicht geklappt hat (einmalig).
    func consumeNotice() async -> String?

    func photoData(for photo: PlacePhoto) async throws -> Data

    /// Googles Place-IDs für den Export als Google-Maps-Liste, in derselben Reihenfolge –
    /// `nil` für Orte, die Google nicht kennt. Insgesamt `nil`, wenn Google gerade nicht erreichbar ist.
    func googlePlaceIDs(for places: [Place]) async -> [String?]?
}

extension PlacesService {
    func googlePlaceIDs(for places: [Place]) async -> [String?]? { nil }
}

nonisolated enum PlacesError: LocalizedError, Equatable {
    case searchFailed

    var errorDescription: String? {
        switch self {
        case .searchFailed: String(localized: "Apple Karten hat gerade nicht geantwortet. Bist du online?")
        }
    }
}
