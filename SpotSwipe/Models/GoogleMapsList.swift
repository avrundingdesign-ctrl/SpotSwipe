import Foundation

/// Gemerkte Orte als Liste in Google Maps.
///
/// Eine Schnittstelle, die Listen direkt im Google-Konto anlegt, gibt es nicht. Google Maps nimmt
/// aber eine Auswahl von Orten als „Shortlist“ entgegen (Maps-URL mit `map_action=shortlist`):
/// Die Google-Maps-App zeigt sie an, dort lässt sie sich mit einem Tipp als Liste speichern und
/// teilen. Die Orte müssen dafür als Google-Place-IDs kommen.
nonisolated enum GoogleMapsList {
    /// So viele Orte nimmt Google Maps in eine Shortlist höchstens auf.
    static let maxPlaces = 20

    /// `nil` ohne eine einzige ID. Leere IDs fallen heraus, über `maxPlaces` hinaus wird gekappt.
    static func shortlistURL(placeIDs: [String]) -> URL? {
        let ids = Array(placeIDs.filter { !$0.isEmpty }.prefix(maxPlaces))
        guard !ids.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.google.com/maps/@")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "map_action", value: "shortlist"),
            URLQueryItem(name: "place_ids", value: ids.joined(separator: ","))
        ]
        return components.url
    }
}
