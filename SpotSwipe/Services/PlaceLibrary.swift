import Foundation
import SwiftData

/// Die Bibliothek aus Sicht des Swipe-Decks. Eigene Abstraktion, damit Tests ohne SwiftData auskommen.
protocol PlaceLibrary {
    func savedPlaceIDs() -> Set<String>
    func save(_ place: Place, searchTerm: String)
    func remove(placeID: String)
}

struct SwiftDataPlaceLibrary: PlaceLibrary {
    let context: ModelContext

    func savedPlaceIDs() -> Set<String> {
        let saved = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
        return Set(saved.map(\.placeID))
    }

    func save(_ place: Place, searchTerm: String) {
        let id = place.id
        let existing = try? context.fetch(FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.placeID == id }))
        if let first = existing?.first {
            first.update(from: place)
        } else {
            context.insert(SavedPlace(place: place, searchTerm: searchTerm))
        }
        try? context.save()
    }

    func remove(placeID: String) {
        let id = placeID
        try? context.delete(model: SavedPlace.self, where: #Predicate { $0.placeID == id })
        try? context.save()
    }
}

enum Persistence {
    /// Mit Team-ID und `SPOTSWIPE_CLOUDKIT = YES` synchronisiert die Bibliothek über iCloud,
    /// sonst bleibt sie lokal. Klappt CloudKit nicht, fällt die App auf lokal zurück statt abzustürzen.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([SavedPlace.self])
        if !inMemory, AppConfig.isCloudSyncEnabled {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(AppConfig.cloudContainerID))
            if let container = try? ModelContainer(for: schema, configurations: cloud) { return container }
        }
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("SwiftData-Container konnte nicht angelegt werden: \(error)")
        }
    }
}
