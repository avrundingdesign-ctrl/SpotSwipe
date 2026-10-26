import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.cardsPerRound) private var cardsPerRound = CardsPerRound.standard
    @AppStorage(SettingsKey.defaultRadiusIndex) private var defaultRadiusIndex = SearchRadius.defaultIndex
    @AppStorage(SettingsKey.onlyOpenNow) private var onlyOpenNow = true
    @AppStorage(SettingsKey.hideSavedPlaces) private var hideSavedPlaces = true
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue

    @State private var confirmsClearing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle("Swipen")
                SectionCard {
                    row(title: "Karten pro Runde", subtitle: "Höchstens so viele Orte pro Suche") {
                        Picker("Karten pro Runde", selection: $cardsPerRound) {
                            ForEach(CardsPerRound.options, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 112)
                    }
                    SectionDivider()
                    row(title: "Standard-Umkreis") {
                        Picker("Standard-Umkreis", selection: $defaultRadiusIndex) {
                            ForEach(SearchRadius.options.indices, id: \.self) { index in
                                Text(Formatters.radius(SearchRadius.options[index])).tag(index)
                            }
                        }
                        .tint(Theme.textSecondary)
                    }
                    SectionDivider()
                    row(title: "Nur geöffnete Orte", subtitle: "Geschlossene werden ausgeblendet") {
                        Toggle("Nur geöffnete Orte", isOn: $onlyOpenNow).labelsHidden().tint(Theme.accent)
                    }
                    SectionDivider()
                    row(title: "Gemerkte ausblenden", subtitle: "Schon gespeicherte nicht erneut zeigen") {
                        Toggle("Gemerkte ausblenden", isOn: $hideSavedPlaces).labelsHidden().tint(Theme.accent)
                    }
                }

                sectionTitle("Darstellung")
                Picker("Darstellung", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                sectionTitle("Bibliothek")
                SectionCard {
                    row(title: "iCloud-Sync", subtitle: AppConfig.isCloudSyncEnabled ? "Gemerkte Orte auf all deinen Geräten" : "Gemerkte Orte bleiben auf diesem iPhone") {
                        if AppConfig.isCloudSyncEnabled {
                            Label("Aktiv", systemImage: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.success)
                        } else {
                            Text("Aus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    SectionDivider()
                    Button {
                        confirmsClearing = true
                    } label: {
                        Text("Bibliothek leeren …")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                sectionTitle("Über")
                SectionCard {
                    NavigationLink {
                        SourcesView()
                    } label: {
                        row(title: "Quellen & Lizenzen") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    SectionDivider()
                    row(title: "Version") {
                        Text(AppConfig.versionString)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("Alle gemerkten Orte löschen?", isPresented: $confirmsClearing, titleVisibility: .visible) {
            Button("Bibliothek leeren", role: .destructive) {
                try? context.delete(model: SavedPlace.self)
                try? context.save()
            }
        } message: {
            Text(AppConfig.isCloudSyncEnabled ? "Das gilt auch für deine anderen Geräte." : "Das lässt sich nicht rückgängig machen.")
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.textSecondary)
            .padding(.leading, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func row<Trailing: View>(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

struct SourcesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Orte, Bewertungen, Öffnungszeiten und Fotos stammen von Google Maps. Die Fotos gehören den jeweils genannten Urheberinnen und Urhebern.")
                Text("Karten, Adresssuche und Routen: Apple Maps.")
                Text("SpotSwipe speichert gemerkte Orte auf deinem Gerät und – wenn eingeschaltet – in deiner privaten iCloud. Es gibt keinen eigenen Server und kein Tracking.")
            }
            .font(.system(size: 16))
            .foregroundStyle(Theme.textPrimary)
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Quellen & Lizenzen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
