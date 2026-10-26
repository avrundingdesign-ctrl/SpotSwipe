import Foundation
import SwiftUI

/// Werte aus Info.plist (gespeist aus Config/*.xcconfig) und Launch-Argumenten.
/// Die App enthält keinen API-Key: Google läuft über den Meanwhile-Proxy (siehe `ProxyService`).
nonisolated enum AppConfig {
    /// Beispieldaten statt Apple Karten und Proxy, per Launch-Argument `-useMockPlaces`.
    static var usesMockPlaces: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockPlaces")
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
    static let hasSeenIntro = "hasSeenIntro"
    static let aiSearchEnabled = "aiSearchEnabled"
    static let aiProvider = "aiProvider"
    static let hasSeenAIInfo = "hasSeenAIInfo"
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
        case .system: String(localized: "System")
        case .light: String(localized: "Hell")
        case .dark: String(localized: "Dunkel")
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
