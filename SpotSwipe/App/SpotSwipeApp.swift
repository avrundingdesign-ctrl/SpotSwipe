import SwiftData
import SwiftUI

@main
struct SpotSwipeApp: App {
    @State private var app = AppModel()
    private let container = Persistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            Tab("Entdecken", systemImage: "safari", value: AppTab.discover) {
                NavigationStack { HomeView() }
            }
            Tab("Bibliothek", systemImage: "bookmark", value: AppTab.library) {
                NavigationStack { LibraryView() }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
        .task {
            app.location.start()
            #if DEBUG
            if DemoLaunch.seedsLibrary { DemoLaunch.seedLibrary(into: context, near: app.searchCenter ?? .cologne) }
            if DemoLaunch.tab == "library" { app.selectedTab = .library }
            #endif
        }
    }
}
