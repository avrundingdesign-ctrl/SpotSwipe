import Foundation
import SwiftUI

/// Werte aus Info.plist (gespeist aus Config/*.xcconfig) und Launch-Argumenten.
nonisolated enum AppConfig {
    static var googlePlacesAPIKey: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String
        return value?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    /// Beispieldaten statt Google: per Launch-Argument `-useMockPlaces` oder automatisch ohne API-Key.
    static var usesMockPlaces: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockPlaces") || googlePlacesAPIKey.isEmpty
    }

    static var isCloudSyncEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "SpotSwipeCloudKitEnabled") as? String)?.uppercased() == "YES"
    }

    static var cloudContainerID: String {
        "iCloud." + (Bundle.main.bundleIdentifier ?? "de.example.spotswipe")
    }

    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Schlüssel für `@AppStorage`. Standardwerte stehen jeweils am Verwendungsort.
nonisolated enum SettingsKey {
    static let cardsPerRound = "cardsPerRound"
    static let defaultRadiusIndex = "defaultRadiusIndex"
    static let onlyOpenNow = "onlyOpenNow"
    static let hideSavedPlaces = "hideSavedPlaces"
    static let appearance = "appearance"
    static let recentSearches = "recentSearches"
}

nonisolated enum CardsPerRound {
    static let options = [5, 10]
    static let standard = 10
}

nonisolated enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
