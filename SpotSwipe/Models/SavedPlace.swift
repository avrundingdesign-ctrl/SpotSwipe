import Foundation
import SwiftData

/// Gemerkter Ort in der Bibliothek, per CloudKit synchronisierbar.
///
/// CloudKit verlangt: alle Felder optional oder mit Standardwert, keine Unique-Constraints.
/// Dubletten verhindert `SwiftDataPlaceLibrary` über `placeID`.
///
/// Bewertung, Fotos und Öffnungszeiten stammen von Google und sind nur ein Schnappschuss;
/// die Detailansicht frischt sie regelmäßig über den Proxy auf.
@Model
final class SavedPlace {
    var placeID: String = ""
    var name: String = ""
    var category: String?
    var address: String?
    var shortAddress: String?
    var city: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var phoneNumber: String?
    var websiteURLString: String?
    var rating: Double?
    var userRatingCount: Int?
    var priceLevelRaw: String?
    var photoURLStrings: [String] = []
    var photoAuthors: [String] = []
    var weekdayHours: [String] = []
    var aiReason: String?
    /// Googles Place-ID, erst beim Export als Google-Maps-Liste nachgeschlagen. Google erlaubt,
    /// sie dauerhaft zu speichern – so wird jeder Ort nur einmal gesucht.
    var googlePlaceID: String?
    var searchTerm: String = ""
    var savedAt: Date = Date.now
    var snapshotFetchedAt: Date = Date.now

    init(place: Place, searchTerm: String, savedAt: Date = .now) {
        self.placeID = place.id
        self.searchTerm = searchTerm
        self.savedAt = savedAt
        update(from: place)
    }

    func update(from place: Place) {
        name = place.name
        category = place.category
        address = place.address
        shortAddress = place.shortAddress
        city = place.city
        latitude = place.location.latitude
        longitude = place.location.longitude
        phoneNumber = place.phoneNumber
        websiteURLString = place.websiteURL?.absoluteString
        // Google-Daten nur überschreiben, wenn welche da sind – sonst
        // löscht ein Ort ohne Proxy-Antwort den älteren Schnappschuss.
        if place.rating != nil { rating = place.rating }
        if place.userRatingCount != nil { userRatingCount = place.userRatingCount }
        if let priceLevel = place.priceLevel { priceLevelRaw = priceLevel.rawValue }
        if !place.photos.isEmpty {
            photoURLStrings = place.photos.map(\.url.absoluteString)
            photoAuthors = place.photos.map { $0.authorName ?? "" }
        }
        if !place.weekdayHours.isEmpty { weekdayHours = place.weekdayHours }
        if let reason = place.aiReason { aiReason = reason }
        snapshotFetchedAt = .now
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// Der gespeicherte Schnappschuss als `Place` (ohne Live-Öffnungsstatus).
    var asPlace: Place {
        let photos = photoURLStrings.enumerated().compactMap { index, string -> PlacePhoto? in
            guard let url = URL(string: string) else { return nil }
            let author = photoAuthors.indices.contains(index) ? photoAuthors[index] : ""
            return PlacePhoto(url: url, authorName: author.isEmpty ? nil : author)
        }
        return Place(
            id: placeID,
            name: name,
            category: category,
            address: address,
            shortAddress: shortAddress,
            city: city,
            location: location,
            phoneNumber: phoneNumber,
            websiteURL: websiteURLString.flatMap(URL.init(string:)),
            rating: rating,
            userRatingCount: userRatingCount,
            priceLevel: priceLevelRaw.flatMap(PriceLevel.init(rawValue:)),
            weekdayHours: weekdayHours,
            photos: photos,
            aiReason: aiReason
        )
    }

    /// "Café · Köln"
    var subtitle: String {
        [category, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
