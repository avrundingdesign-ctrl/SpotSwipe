import Foundation
import SwiftData

/// Gemerkter Ort in der Bibliothek, per CloudKit synchronisierbar.
///
/// CloudKit verlangt: alle Felder optional oder mit Standardwert, keine Unique-Constraints.
/// Dubletten verhindert `SwiftDataPlaceLibrary` über `placeID`.
///
/// Google erlaubt dauerhaftes Speichern eigentlich nur für die Place-ID. Der Rest ist ein
/// Schnappschuss, den die Detailansicht regelmäßig über Place Details auffrischt.
@Model
final class SavedPlace {
    var placeID: String = ""
    var name: String = ""
    var category: String?
    var address: String?
    var shortAddress: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var rating: Double?
    var userRatingCount: Int?
    var priceLevelRaw: String?
    var phoneNumber: String?
    var websiteURLString: String?
    var googleMapsURLString: String?
    var photoNames: [String] = []
    var photoAuthors: [String] = []
    var weekdayHours: [String] = []
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
        latitude = place.location.latitude
        longitude = place.location.longitude
        rating = place.rating
        userRatingCount = place.userRatingCount
        priceLevelRaw = place.priceLevel?.rawValue
        phoneNumber = place.phoneNumber
        websiteURLString = place.websiteURL?.absoluteString
        googleMapsURLString = place.googleMapsURL?.absoluteString
        photoNames = place.photos.map(\.name)
        photoAuthors = place.photos.map { $0.authorName ?? "" }
        weekdayHours = place.weekdayHours
        snapshotFetchedAt = .now
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// Der gespeicherte Schnappschuss als `Place` (ohne Live-Öffnungsstatus).
    var asPlace: Place {
        let photos = photoNames.enumerated().map { index, name in
            let author = photoAuthors.indices.contains(index) ? photoAuthors[index] : ""
            return PlacePhoto(name: name, authorName: author.isEmpty ? nil : author)
        }
        return Place(
            id: placeID,
            name: name,
            category: category,
            address: address,
            shortAddress: shortAddress,
            location: location,
            rating: rating,
            userRatingCount: userRatingCount,
            priceLevel: priceLevelRaw.flatMap(PriceLevel.init(rawValue:)),
            weekdayHours: weekdayHours,
            phoneNumber: phoneNumber,
            websiteURL: websiteURLString.flatMap(URL.init(string:)),
            googleMapsURL: googleMapsURLString.flatMap(URL.init(string:)),
            photos: photos
        )
    }

    /// "Café · Köln": Kategorie und Ort aus der Kurzadresse.
    var subtitle: String {
        let city = shortAddress?.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) }
        return [category, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
