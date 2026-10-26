import UIKit

/// Erfundene Orte rund um den Suchmittelpunkt – für Tests, Previews und Screenshots
/// (Launch-Argument `-useMockPlaces`). Liefert wie der echte Dienst erst die Grunddaten
/// und Fotos, Bewertung und Öffnungsstatus getrennt über `extras(for:)`.
final class MockPlacesService: PlacesService {
    let attribution = "Beispieldaten"

    private static let names = [
        "Café Liebling", "Bohne & Brot", "Kaffeekontor", "Milchschaum", "Röstwerk 7",
        "Kleine Pause", "Zuckerstück", "Fräulein Bohne", "Morgenrot", "Tassenglück",
        "Eckcafé", "Feierabend", "Hafenblick", "Lindenhof"
    ]

    private let delay: Duration

    init(delay: Duration = .milliseconds(400)) {
        self.delay = delay
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        try await Task.sleep(for: delay)
        return Self.makePlaces(query: query)
    }

    func extras(for place: Place) async -> PlaceExtras? {
        try? await Task.sleep(for: delay / 2)
        return Self.extras(for: place)
    }

    func consumeNotice() async -> String? { nil }

    func photoData(for photo: PlacePhoto) async throws -> Data {
        try await Task.sleep(for: .milliseconds(80))
        return Self.renderPhoto(seed: photo.url.absoluteString, width: 900)
    }

    static func makePlaces(query: PlaceSearchQuery) -> [Place] {
        let category = query.text.prefix(1).uppercased() + query.text.dropFirst()
        return names.enumerated().map { index, name in
            // Spirale um den Mittelpunkt; die letzten Orte liegen absichtlich außerhalb des Radius.
            let fraction = 0.12 + Double(index) / Double(names.count) * 1.1
            let distance = query.radius * fraction
            let angle = Double(index) * 2.4
            let dLat = distance * cos(angle) / GeoMath.earthRadius * 180 / .pi
            let dLon = distance * sin(angle) / GeoMath.earthRadius * 180 / .pi / cos(query.center.latitude * .pi / 180)
            return Place(
                id: "mock-\(index)-\(query.text.lowercased())",
                name: name,
                category: category,
                address: "Venloer Straße \(12 + index * 17), 50823 Köln",
                shortAddress: "Venloer Str. \(12 + index * 17)",
                city: "Köln",
                location: GeoPoint(latitude: query.center.latitude + dLat, longitude: query.center.longitude + dLon),
                phoneNumber: index % 4 == 2 ? nil : "0221 \(100_000 + index * 7_919)",
                websiteURL: index % 3 == 1 ? nil : URL(string: "https://www.apple.com/de/maps/")
            )
        }
    }

    /// Jeder fünfte Ort hat geschlossen, damit sich „Nur geöffnete“ testen lässt.
    static func extras(for place: Place) -> PlaceExtras {
        let index = Int(place.id.split(separator: "-").dropFirst().first ?? "0") ?? 0
        return PlaceExtras(
            rating: 3.9 + Double(index % 10) / 10,
            ratingCount: 40 + index * 73,
            priceLevel: [.inexpensive, .moderate, .moderate, .expensive][index % 4],
            isOpenNow: index % 5 != 3,
            nextCloseTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
            weekdayHours: [
                "Montag: 08:00–18:00", "Dienstag: 08:00–18:00", "Mittwoch: 08:00–18:00",
                "Donnerstag: 08:00–18:00", "Freitag: 08:00–18:00", "Samstag: 09:00–18:00", "Sonntag: 10:00–17:00"
            ],
            photos: (0..<(3 + index % 3)).map {
                PlacePhoto(url: URL(string: "mock://photo/\(place.id)/\($0)")!, authorName: "Beispiel")
            }
        )
    }

    /// Ruhiger Verlauf in den Platzhalterfarben des Designs.
    static func renderPhoto(seed: String, width: Int) -> Data {
        let size = CGSize(width: width, height: Int(Double(width) * 1.4))
        let colors = Theme.photoPalettes.map { (UIColor($0.0), UIColor($0.1)) }
        let hash = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        let (top, bottom) = colors[hash % colors.count]
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width * 0.6, y: size.height),
                options: []
            )
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
