import Foundation

/// Ein Ort, wie ihn die Swipe-Karte und die Detailansicht zeigen.
///
/// Grunddaten (Name, Adresse, Telefon, Website, Koordinate) kommen kostenlos von
/// Apple Karten. Bewertung, Fotos und Öffnungszeiten ergänzt Google über den
/// Meanwhile-Proxy (`PlaceExtras`), sobald die Karte an der Reihe ist.
nonisolated struct Place: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var category: String?
    var address: String?
    var shortAddress: String?
    var city: String?
    var location: GeoPoint
    var phoneNumber: String?
    var websiteURL: URL?

    var rating: Double?
    var userRatingCount: Int?
    var priceLevel: PriceLevel?
    var isOpenNow: Bool?
    var nextCloseTime: Date?
    var weekdayHours: [String] = []
    var photos: [PlacePhoto] = []

    func distance(from point: GeoPoint) -> Double {
        GeoMath.distance(from: point, to: location)
    }

    var openingStatus: String? {
        Formatters.openingStatus(isOpen: isOpenNow, nextClose: nextCloseTime)
    }

    /// Ergänzt die Google-Daten. Was der Proxy nicht kennt, bleibt wie es ist.
    func merging(_ extras: PlaceExtras) -> Place {
        var copy = self
        copy.rating = extras.rating ?? rating
        copy.userRatingCount = extras.ratingCount ?? userRatingCount
        copy.priceLevel = extras.priceLevel ?? priceLevel
        copy.isOpenNow = extras.isOpenNow ?? isOpenNow
        copy.nextCloseTime = extras.nextCloseTime ?? nextCloseTime
        if !extras.weekdayHours.isEmpty { copy.weekdayHours = extras.weekdayHours }
        if !extras.photos.isEmpty { copy.photos = extras.photos }
        return copy
    }

    /// Link zum Teilen: der Ort in Apple Karten.
    var shareURL: URL { appleMapsURL }

    var appleMapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)")
        ]
        return components.url!
    }

    var routeURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "daddr", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components.url!
    }

    var phoneURL: URL? {
        guard let phoneNumber else { return nil }
        let digits = phoneNumber.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }
}

/// Ein Foto mit Pflicht-Attribution (Google verlangt den Urheber am Bild).
nonisolated struct PlacePhoto: Hashable, Sendable {
    let url: URL
    var authorName: String?
}

/// Was Google über den Proxy zu einem Ort beisteuert.
nonisolated struct PlaceExtras: Hashable, Sendable {
    var rating: Double?
    var ratingCount: Int?
    var priceLevel: PriceLevel?
    var isOpenNow: Bool?
    var nextCloseTime: Date?
    var weekdayHours: [String] = []
    var photos: [PlacePhoto] = []
}

nonisolated enum PriceLevel: String, Sendable, CaseIterable {
    case free = "PRICE_LEVEL_FREE"
    case inexpensive = "PRICE_LEVEL_INEXPENSIVE"
    case moderate = "PRICE_LEVEL_MODERATE"
    case expensive = "PRICE_LEVEL_EXPENSIVE"
    case veryExpensive = "PRICE_LEVEL_VERY_EXPENSIVE"

    var symbol: String {
        switch self {
        case .free: "Kostenlos"
        case .inexpensive: "€"
        case .moderate: "€€"
        case .expensive: "€€€"
        case .veryExpensive: "€€€€"
        }
    }
}

/// Ein vom Nutzer gewählter Suchmittelpunkt.
nonisolated struct SearchLocation: Hashable, Sendable {
    var name: String
    var subtitle: String?
    var point: GeoPoint
}

/// Alles, was eine Swipe-Runde braucht.
nonisolated struct SearchRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    var query: String
    var center: GeoPoint
    var centerName: String?
    var radius: Double
    var cardsPerRound: Int
    var onlyOpenNow: Bool
    var hideSaved: Bool
}

nonisolated enum SearchRadius {
    static let options: [Double] = [500, 1_000, 2_000, 5_000, 10_000, 25_000]
    static let defaultIndex = 2

    static func value(at index: Int) -> Double {
        options[min(max(index, 0), options.count - 1)]
    }
}
