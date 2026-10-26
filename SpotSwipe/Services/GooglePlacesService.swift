import Foundation

/// Google Places API (New): Text Search, Place Details und Fotos.
///
/// Der Key sollte in der Google Cloud Console auf die iOS-Bundle-ID und auf
/// „Places API (New)“ beschränkt sein. Deshalb schicken wir bei jeder Anfrage
/// `X-Ios-Bundle-Identifier` mit.
final class GooglePlacesService: PlacesService {
    /// Nur diese Felder werden abgerechnet. Telefon, Website und Bewertung liegen
    /// in der teureren Stufe, sind für die Karte aber nötig.
    static let fields = [
        "id", "displayName", "formattedAddress", "shortFormattedAddress", "location",
        "rating", "userRatingCount", "priceLevel",
        "currentOpeningHours.openNow", "currentOpeningHours.nextCloseTime",
        "regularOpeningHours.weekdayDescriptions",
        "nationalPhoneNumber", "websiteUri", "googleMapsUri", "photos", "primaryTypeDisplayName"
    ]

    let attribution = "Orte und Fotos: Google Maps"

    private let apiKey: String
    private let bundleID: String
    private let session: URLSession

    init(apiKey: String, bundleID: String = Bundle.main.bundleIdentifier ?? "", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.bundleID = bundleID
        self.session = session
    }

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        let box = GeoMath.boundingBox(center: query.center, radius: query.radius)
        let body = SearchTextRequest(
            textQuery: query.text,
            openNow: query.onlyOpenNow ? true : nil,
            locationRestriction: .init(rectangle: .init(low: GoogleLatLng(box.low), high: GoogleLatLng(box.high)))
        )
        var request = makeRequest(
            url: URL(string: "https://places.googleapis.com/v1/places:searchText")!,
            fieldMask: Self.fields.map { "places." + $0 }.joined(separator: ",")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let response: SearchTextResponse = try await send(request)
        return (response.places ?? []).compactMap(\.place)
    }

    func placeDetails(id: String) async throws -> Place {
        let request = makeRequest(
            url: URL(string: "https://places.googleapis.com/v1/places/\(id)?languageCode=de")!,
            fieldMask: Self.fields.joined(separator: ",")
        )
        let dto: PlaceDTO = try await send(request)
        guard let place = dto.place else { throw PlacesError.decoding }
        return place
    }

    func photoData(for photo: PlacePhoto, maxWidth: Int) async throws -> Data {
        let url = URL(string: "https://places.googleapis.com/v1/\(photo.name)/media?maxWidthPx=\(maxWidth)")!
        let (data, response) = try await session.data(for: makeRequest(url: url, fieldMask: nil))
        guard let http = response as? HTTPURLResponse else { throw PlacesError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw PlacesError.http(status: http.statusCode, message: nil)
        }
        return data
    }

    private func makeRequest(url: URL, fieldMask: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        if let fieldMask {
            request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlacesError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? GooglePlacesCoding.decoder.decode(GoogleErrorEnvelope.self, from: data))?.error.message
            throw PlacesError.http(status: http.statusCode, message: message)
        }
        do {
            return try GooglePlacesCoding.decoder.decode(T.self, from: data)
        } catch {
            throw PlacesError.decoding
        }
    }
}
