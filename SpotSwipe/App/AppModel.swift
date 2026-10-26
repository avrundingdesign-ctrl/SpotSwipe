import Foundation
import Observation

enum AppTab: Hashable {
    case discover, library
}

/// App-weiter Zustand: Dienste, gewählter Suchort und aktiver Tab.
@Observable
final class AppModel {
    let places: any PlacesService
    let location: LocationService
    let isMockData: Bool

    /// `nil` heißt: am aktuellen Standort suchen.
    var selectedLocation: SearchLocation?
    var selectedTab: AppTab = .discover

    init(places: (any PlacesService)? = nil, location: LocationService = LocationService()) {
        if let places {
            self.places = places
        } else if AppConfig.usesMockPlaces {
            self.places = MockPlacesService()
        } else {
            self.places = AppleMapsPlacesService()
        }
        self.isMockData = self.places is MockPlacesService
        self.location = location
    }

    /// Mittelpunkt der Suche. Mit Beispieldaten notfalls Köln, damit man ohne Standort testen kann.
    var searchCenter: GeoPoint? {
        selectedLocation?.point ?? location.currentPoint ?? (isMockData ? .cologne : nil)
    }

    /// Ortsname für Überschriften („2 km um Köln“). `nil`, solange der Name noch nicht bekannt ist.
    var searchCenterPlaceName: String? {
        selectedLocation?.name ?? location.currentPlaceName ?? (isMockData && location.currentPoint == nil ? "Köln" : nil)
    }

    /// Text im Standort-Chip.
    var searchCenterName: String {
        if let name = searchCenterPlaceName { return name }
        if location.currentPoint != nil { return String(localized: "Mein Standort") }
        return location.isAuthorized ? String(localized: "Standort …") : String(localized: "Standort wählen")
    }
}
