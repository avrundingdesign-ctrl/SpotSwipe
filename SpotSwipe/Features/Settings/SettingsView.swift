import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.cardsPerRound) private var cardsPerRound = CardsPerRound.standard
    @AppStorage(SettingsKey.defaultRadiusIndex) private var defaultRadiusIndex = SearchRadius.defaultIndex
    @AppStorage(SettingsKey.onlyOpenNow) private var onlyOpenNow = true
    @AppStorage(SettingsKey.hideSavedPlaces) private var hideSavedPlaces = true
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.hasSeenIntro) private var hasSeenIntro = true
    @AppStorage(SettingsKey.aiSearchEnabled) private var aiSearchEnabled = false
    @AppStorage(SettingsKey.hasSeenAIInfo) private var hasSeenAIInfo = false
    @AppStorage(SettingsKey.aiProvider) private var aiProvider = AIProvider.claude.rawValue

    @Environment(\.openURL) private var openURL
    @State private var confirmsClearing = false

    /// Name der aktuellen App-Sprache in dieser Sprache ("Deutsch", "English" …).
    private var languageName: String {
        let code = AppLanguage.code
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized(with: Locale(identifier: code)) ?? code
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle("Swipen")
                SectionCard {
                    row(title: "Karten pro Runde", subtitle: "Höchstens so viele Orte pro Suche") {
                        Picker("Karten pro Runde", selection: $cardsPerRound) {
                            ForEach(CardsPerRound.options, id: \.self) { Text(verbatim: "\($0)").tag($0) }
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

                sectionTitle("KI-Suche")
                SectionCard {
                    row(title: "KI-Suche", subtitle: "Versteht Wünsche wie „ruhiges Café zum Arbeiten“") {
                        Toggle("KI-Suche", isOn: $aiSearchEnabled).labelsHidden().tint(Theme.accent)
                    }
                    SectionDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anbieter")
                            .font(.system(size: 16, weight: .semibold))
                        Picker("Anbieter", selection: $aiProvider) {
                            ForEach(AIProvider.allCases) { Text(verbatim: $0.label).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        Text(providerNote)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
                Text("Mit KI dauert die Suche etwas länger, die Treffer passen aber besser. Bei Claude gehen dein Suchwunsch und die Namen der gefundenen Orte über unseren Server an Anthropic, nicht dein Standort. Apple Intelligence rechnet direkt auf dem iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                sectionTitle("Darstellung")
                Picker("Darstellung", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                SectionCard {
                    // Die App-Sprache stellt iOS pro App ein (Einstellungen › SpotSwipe › Sprache).
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        row(title: "Sprache") {
                            HStack(spacing: 6) {
                                Text(verbatim: languageName)
                                    .foregroundStyle(Theme.textSecondary)
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .font(.system(size: 16))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

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

                sectionTitle("Rechtliches")
                SectionCard {
                    NavigationLink {
                        LegalTextView(document: .imprint)
                    } label: {
                        row(title: "Impressum") { chevron }
                    }
                    .buttonStyle(.plain)
                    SectionDivider()
                    NavigationLink {
                        LegalTextView(document: .privacy)
                    } label: {
                        row(title: "Datenschutz") { chevron }
                    }
                    .buttonStyle(.plain)
                    SectionDivider()
                    Link(destination: URL(string: "mailto:\(AppConfig.supportEmail)")!) {
                        row(title: "Kontakt", subtitle: LocalizedStringKey(stringLiteral: AppConfig.supportEmail)) {
                            Image(systemName: "envelope")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
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
                    Button {
                        hasSeenIntro = false
                    } label: {
                        row(title: "Intro noch einmal ansehen") {
                            Image(systemName: "play.circle")
                                .font(.system(size: 18, weight: .semibold))
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
        .onChange(of: aiSearchEnabled) { _, isOn in
            if isOn { hasSeenAIInfo = true }
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("Alle gemerkten Orte löschen?", isPresented: $confirmsClearing, titleVisibility: .visible) {
            Button("Bibliothek leeren", role: .destructive) {
                try? context.delete(model: SavedPlace.self)
                try? context.save()
            }
        } message: {
            if AppConfig.isCloudSyncEnabled {
                Text("Das gilt auch für deine anderen Geräte.")
            } else {
                Text("Das lässt sich nicht rückgängig machen.")
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
    }

    private var providerNote: String {
        let appleAvailable = AppleIntelligenceAssistant.isAvailable
        if AIProvider(rawValue: aiProvider) == .apple {
            return appleAvailable
                ? String(localized: "Läuft auf dem iPhone, kostenlos und privat. Fallback: Claude.")
                : String(localized: "Auf diesem iPhone nicht verfügbar – Swipez nutzt Claude.")
        }
        return appleAvailable
            ? String(localized: "Fallback: Apple Intelligence auf dem iPhone.")
            : String(localized: "Fallback: keiner – Apple Intelligence ist auf diesem iPhone nicht verfügbar.")
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.textSecondary)
            .padding(.leading, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func row<Trailing: View>(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
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
                Text("Orte, Adressen, Karten und Routen: Apple Karten.")
                Text("KI-Suche: Claude von Anthropic über unseren Server oder Apple Intelligence auf dem iPhone.")
                Text("Bewertungen, Öffnungszeiten und Fotos: Google Maps. Die Fotos gehören den jeweils genannten Urheberinnen und Urhebern.")
                Text("Für Fotos und Bewertungen fragt Swipez über einen eigenen Server bei Google an. Dabei werden nur Name und Lage des Orts übertragen, nicht dein Standort.")
                Text("Gemerkte Orte speichert Swipez auf deinem Gerät und – wenn eingeschaltet – in deiner privaten iCloud. Es gibt kein Tracking und keine Werbung.")
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
