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
}

nonisolated enum PlacesError: LocalizedError, Equatable {
    case searchFailed

    var errorDescription: String? {
        switch self {
        case .searchFailed: "Apple Karten hat gerade nicht geantwortet. Bist du online?"
        }
    }
}
