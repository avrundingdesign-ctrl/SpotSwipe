#if DEBUG
import Foundation
import SwiftData

/// Nur im Debug-Build: Startargumente, die direkt in einen Zustand springen (für Screenshots im Simulator).
///
///     -demoSearch Café             startet sofort eine Swipe-Runde
///     -demoScreen settings|location|map|detail|finished|drag
///     -demoTab library             öffnet die Bibliothek
///     -demoSeedLibrary YES         legt Beispielorte in der Bibliothek an
///     -hasSeenIntro NO -demoIntroPage 1   zeigt das Intro ab Seite 2
enum DemoLaunch {
    static var search: String? { UserDefaults.standard.string(forKey: "demoSearch") }
    static var screen: String? { UserDefaults.standard.string(forKey: "demoScreen") }
    static var tab: String? { UserDefaults.standard.string(forKey: "demoTab") }
    static var seedsLibrary: Bool { UserDefaults.standard.bool(forKey: "demoSeedLibrary") }
    /// `-demoIntroPage 2` öffnet das Intro auf Seite 3 (zusammen mit `-hasSeenIntro NO`).
    static var introPage: Int { UserDefaults.standard.integer(forKey: "demoIntroPage") }

    static func seedLibrary(into context: ModelContext, near center: GeoPoint) {
        let existing = (try? context.fetchCount(FetchDescriptor<SavedPlace>())) ?? 0
        guard existing == 0 else { return }
        let terms = ["Café", "Pizza", "Café", "Park", "Bar", "Café"]
        let places = MockPlacesService.makePlaces(query: PlaceSearchQuery(text: "Café", center: center, radius: 2_000))
        for (index, place) in places.prefix(terms.count).enumerated() {
            var copy = place.merging(MockPlacesService.extras(for: place))
            copy.category = terms[index]
            context.insert(SavedPlace(place: copy, searchTerm: terms[index], savedAt: .now.addingTimeInterval(-Double(index) * 3_600)))
        }
        try? context.save()
    }
}
#endif
