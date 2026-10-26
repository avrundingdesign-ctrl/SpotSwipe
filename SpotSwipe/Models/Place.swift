import Foundation

/// Ein Ort, wie ihn die Swipe-Karte und die Detailansicht zeigen.
nonisolated struct Place: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var category: String?
    var address: String?
    var shortAddress: String?
    var location: GeoPoint
    var rating: Double?
    var userRatingCount: Int?
    var priceLevel: PriceLevel?
    var isOpenNow: Bool?
    var nextCloseTime: Date?
    var weekdayHours: [String] = []
    var phoneNumber: String?
    var websiteURL: URL?
    var googleMapsURL: URL?
    var photos: [PlacePhoto] = []

    func distance(from point: GeoPoint) -> Double {
        GeoMath.distance(from: point, to: location)
    }

    var openingStatus: String? {
        Formatters.openingStatus(isOpen: isOpenNow, nextClose: nextCloseTime)
    }

    /// Link zum Teilen: Google-Maps-Seite des Orts, sonst Apple Maps.
    var shareURL: URL {
        googleMapsURL ?? appleMapsURL
    }

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

nonisolated struct PlacePhoto: Hashable, Sendable {
    /// Ressourcenname bei Google, z. B. `places/ChIJ…/photos/Aap…`.
    let name: String
    var width: Int?
    var height: Int?
    var authorName: String?
    var authorURL: URL?
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
    static let shortLabels = ["0,5", "1", "2", "5", "10", "25 km"]
    static let defaultIndex = 2

    static func value(at index: Int) -> Double {
        options[min(max(index, 0), options.count - 1)]
    }
}
