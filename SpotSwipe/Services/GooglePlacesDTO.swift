import Foundation

// Wire-Formate der Google Places API (New).
// https://developers.google.com/maps/documentation/places/web-service/text-search

nonisolated struct GoogleLatLng: Codable, Sendable {
    var latitude: Double
    var longitude: Double

    init(_ point: GeoPoint) {
        latitude = point.latitude
        longitude = point.longitude
    }
}

nonisolated struct SearchTextRequest: Encodable, Sendable {
    nonisolated struct Rectangle: Encodable, Sendable {
        var low: GoogleLatLng
        var high: GoogleLatLng
    }

    nonisolated struct Restriction: Encodable, Sendable {
        var rectangle: Rectangle
    }

    var textQuery: String
    var languageCode = "de"
    var pageSize = 20
    var openNow: Bool?
    var locationRestriction: Restriction
}

nonisolated struct SearchTextResponse: Decodable, Sendable {
    var places: [PlaceDTO]?
}

nonisolated struct PlaceDTO: Decodable, Sendable {
    nonisolated struct LocalizedText: Decodable, Sendable {
        var text: String?
    }

    nonisolated struct OpeningHours: Decodable, Sendable {
        var openNow: Bool?
        var nextCloseTime: Date?
        var weekdayDescriptions: [String]?
    }

    nonisolated struct Photo: Decodable, Sendable {
        nonisolated struct Author: Decodable, Sendable {
            var displayName: String?
            var uri: String?
        }

        var name: String
        var widthPx: Int?
        var heightPx: Int?
        var authorAttributions: [Author]?
    }

    var id: String
    var displayName: LocalizedText?
    var formattedAddress: String?
    var shortFormattedAddress: String?
    var location: GoogleLatLng?
    var rating: Double?
    var userRatingCount: Int?
    var priceLevel: String?
    var currentOpeningHours: OpeningHours?
    var regularOpeningHours: OpeningHours?
    var nationalPhoneNumber: String?
    var websiteUri: String?
    var googleMapsUri: String?
    var photos: [Photo]?
    var primaryTypeDisplayName: LocalizedText?

    /// `nil`, wenn Google keine Koordinate liefert (dann ist der Ort für uns unbrauchbar).
    var place: Place? {
        guard let location else { return nil }
        return Place(
            id: id,
            name: displayName?.text ?? "Unbenannter Ort",
            category: primaryTypeDisplayName?.text,
            address: formattedAddress,
            shortAddress: shortFormattedAddress,
            location: GeoPoint(latitude: location.latitude, longitude: location.longitude),
            rating: rating,
            userRatingCount: userRatingCount,
            priceLevel: priceLevel.flatMap(PriceLevel.init(rawValue:)),
            isOpenNow: currentOpeningHours?.openNow,
            nextCloseTime: currentOpeningHours?.nextCloseTime,
            weekdayHours: regularOpeningHours?.weekdayDescriptions ?? [],
            phoneNumber: nationalPhoneNumber,
            websiteURL: websiteUri.flatMap(URL.init(string:)),
            googleMapsURL: googleMapsUri.flatMap(URL.init(string:)),
            photos: (photos ?? []).map { photo in
                let author = photo.authorAttributions?.first
                return PlacePhoto(
                    name: photo.name,
                    width: photo.widthPx,
                    height: photo.heightPx,
                    authorName: author?.displayName,
                    authorURL: author?.uri.flatMap(URL.init(string:))
                )
            }
        )
    }
}

nonisolated struct GoogleErrorEnvelope: Decodable, Sendable {
    nonisolated struct Body: Decodable, Sendable {
        var code: Int?
        var message: String?
        var status: String?
    }

    var error: Body
}

nonisolated enum GooglePlacesCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
