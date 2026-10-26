@preconcurrency import MapKit

/// Wie in Meanwhile: Orte von Apple Karten (kostenlos, ohne Key), Bewertung,
/// Fotos und Öffnungszeiten von Google über den eigenen Proxy.
final class AppleMapsPlacesService: PlacesService {
    /// Mehr als eine Handvoll Fotos klickt niemand durch, und jedes kostet eine Google-Anfrage.
    static let maxPhotos = 5

    var attribution: String {
        AttestService.isSupported
            ? String(localized: "Orte: Apple Karten · Fotos & Bewertungen: Google")
            : String(localized: "Orte: Apple Karten · Fotos nur auf dem iPhone")
    }

    private var cache: [String: PlaceExtras] = [:]
    /// Orte, die Google nicht eindeutig kennt – nicht erneut anfragen.
    private var missing: Set<String> = []
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    func searchPlaces(_ query: PlaceSearchQuery) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query.text
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: query.center.coordinate,
            latitudinalMeters: query.radius * 2,
            longitudinalMeters: query.radius * 2
        )
        request.regionPriority = .required
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap(Self.place(from:))
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        } catch {
            throw PlacesError.searchFailed
        }
    }

    func extras(for place: Place) async -> PlaceExtras? {
        if let cached = cache[place.id] { return cached }
        guard AttestService.isSupported, !missing.contains(place.id) else { return nil }

        var payload: [String: any Sendable] = [
            "name": place.name,
            "lat": place.location.latitude,
            "lng": place.location.longitude,
            "maxPhotos": Self.maxPhotos
        ]
        if let city = place.city { payload["city"] = city }

        guard let data = await ProxyService.shared.send("v1/place", payload) else { return nil }
        guard let reply = try? JSONDecoder().decode(ProxyPlaceReply.self, from: data) else { return nil }
        guard let extras = reply.extras else {
            missing.insert(place.id)
            return nil
        }
        cache[place.id] = extras
        return extras
    }

    func consumeNotice() async -> String? {
        await ProxyService.shared.consumeNotice()
    }

    /// Fertige Bild-URLs von Google (googleusercontent) – kosten kein Proxy-Kontingent.
    func photoData(for photo: PlacePhoto) async throws -> Data {
        let (data, response) = try await session.data(from: photo.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    // MARK: - Apple Karten → Place

    static func place(from item: MKMapItem) -> Place? {
        guard let name = item.name, !name.isEmpty else { return nil }
        let coordinate = item.location.coordinate
        let fallbackID = String(format: "apple-%@-%.5f,%.5f", name, coordinate.latitude, coordinate.longitude)
        return Place(
            id: item.identifier?.rawValue ?? fallbackID,
            name: name,
            category: item.pointOfInterestCategory.flatMap(categoryName(for:)),
            address: item.address?.fullAddress,
            shortAddress: item.address?.shortAddress,
            city: item.addressRepresentations?.cityName,
            location: GeoPoint(coordinate),
            phoneNumber: item.phoneNumber,
            websiteURL: item.url
        )
    }

    private static let categoryNames: [MKPointOfInterestCategory: String] = [
        .cafe: String(localized: "Café", comment: "Kategorie"),
        .bakery: String(localized: "Bäckerei", comment: "Kategorie"),
        .restaurant: String(localized: "Restaurant", comment: "Kategorie"),
        .nightlife: String(localized: "Bar", comment: "Kategorie"),
        .brewery: String(localized: "Brauerei", comment: "Kategorie"),
        .winery: String(localized: "Weingut", comment: "Kategorie"),
        .distillery: String(localized: "Destillerie", comment: "Kategorie"),
        .foodMarket: String(localized: "Markt", comment: "Kategorie"),
        .park: String(localized: "Park", comment: "Kategorie"),
        .nationalPark: String(localized: "Nationalpark", comment: "Kategorie"),
        .beach: String(localized: "Strand", comment: "Kategorie"),
        .hiking: String(localized: "Wandern", comment: "Kategorie"),
        .museum: String(localized: "Museum", comment: "Kategorie"),
        .theater: String(localized: "Theater", comment: "Kategorie"),
        .movieTheater: String(localized: "Kino", comment: "Kategorie"),
        .musicVenue: String(localized: "Konzerte", comment: "Kategorie"),
        .landmark: String(localized: "Sehenswürdigkeit", comment: "Kategorie"),
        .castle: String(localized: "Burg", comment: "Kategorie"),
        .fortress: String(localized: "Festung", comment: "Kategorie"),
        .nationalMonument: String(localized: "Denkmal", comment: "Kategorie"),
        .library: String(localized: "Bücherei", comment: "Kategorie"),
        .zoo: String(localized: "Zoo", comment: "Kategorie"),
        .aquarium: String(localized: "Aquarium", comment: "Kategorie"),
        .planetarium: String(localized: "Planetarium", comment: "Kategorie"),
        .amusementPark: String(localized: "Freizeitpark", comment: "Kategorie"),
        .fairground: String(localized: "Kirmes", comment: "Kategorie"),
        .store: String(localized: "Laden", comment: "Kategorie"),
        .spa: String(localized: "Spa", comment: "Kategorie"),
        .fitnessCenter: String(localized: "Fitness", comment: "Kategorie"),
        .swimming: String(localized: "Schwimmen", comment: "Kategorie"),
        .bowling: String(localized: "Bowling", comment: "Kategorie"),
        .miniGolf: String(localized: "Minigolf", comment: "Kategorie"),
        .rockClimbing: String(localized: "Klettern", comment: "Kategorie"),
        .hotel: String(localized: "Hotel", comment: "Kategorie"),
        .marina: String(localized: "Hafen", comment: "Kategorie"),
        .stadium: String(localized: "Stadion", comment: "Kategorie")
    ]

    static func categoryName(for category: MKPointOfInterestCategory) -> String? {
        categoryNames[category]
    }
}

/// Antwort von `POST /v1/place`.
nonisolated struct ProxyPlaceReply: Decodable, Sendable {
    nonisolated struct Photo: Decodable, Sendable {
        let url: String
        let attribution: String?
    }

    let found: Bool
    let rating: Double?
    let ratingCount: Int?
    let priceLevel: String?
    let openNow: Bool?
    let nextCloseTime: String?
    let weekdayHours: [String]?
    let photos: [Photo]?

    /// `nil`, wenn Google den Ort nicht (eindeutig) kennt.
    var extras: PlaceExtras? {
        guard found else { return nil }
        return PlaceExtras(
            rating: rating,
            ratingCount: ratingCount,
            priceLevel: priceLevel.flatMap(PriceLevel.init(rawValue:)),
            isOpenNow: openNow,
            nextCloseTime: nextCloseTime.flatMap { try? Date($0, strategy: .iso8601) },
            weekdayHours: weekdayHours ?? [],
            photos: (photos ?? []).compactMap { photo in
                URL(string: photo.url).map { PlacePhoto(url: $0, authorName: photo.attribution) }
            }
        )
    }
}
