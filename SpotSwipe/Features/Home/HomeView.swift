import SwiftData
import SwiftUI

/// Startseite: „Wonach suchst du?“, Umkreis, Go. Standort oben rechts.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.defaultRadiusIndex) private var defaultRadiusIndex = SearchRadius.defaultIndex
    @AppStorage(SettingsKey.cardsPerRound) private var cardsPerRound = CardsPerRound.standard
    @AppStorage(SettingsKey.onlyOpenNow) private var onlyOpenNow = true
    @AppStorage(SettingsKey.hideSavedPlaces) private var hideSavedPlaces = true
    @AppStorage(SettingsKey.recentSearches) private var recentStorage = ""

    @State private var query = ""
    @State private var radiusIndex = SearchRadius.defaultIndex
    @State private var didApplyDefaultRadius = false
    @State private var isLocationPanelOpen = false
    @State private var isMapPickerOpen = false
    @State private var showsSettings = false
    @State private var showsLocationHint = false
    @State private var activeSearch: SearchRequest?
    @FocusState private var isSearchFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 46

    /// Vorschläge in der Sprache der Oberfläche – Apple Karten sucht in jeder Sprache.
    private static let suggestions = [
        String(localized: "Café", comment: "Suchvorschlag"),
        String(localized: "Brunch", comment: "Suchvorschlag"),
        String(localized: "Pizza", comment: "Suchvorschlag"),
        String(localized: "Bar", comment: "Suchvorschlag"),
        String(localized: "Park", comment: "Suchvorschlag"),
        String(localized: "Sushi", comment: "Suchvorschlag"),
        String(localized: "Bäckerei", comment: "Suchvorschlag")
    ]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()
                .onTapGesture { isSearchFocused = false }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    headline.padding(.top, 22)
                    searchField
                    suggestionChips
                    recentRow
                    DistancePicker(index: $radiusIndex)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { goButton }

            if isLocationPanelOpen {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { closeLocationPanel() }
                    .transition(.opacity)
                LocationPanel(
                    onClose: closeLocationPanel,
                    onPickOnMap: { isMapPickerOpen = true }
                )
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .transition(.scale(scale: 0.4, anchor: .topTrailing).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(isLocationPanelOpen ? .hidden : .automatic, for: .tabBar)
        .navigationDestination(isPresented: $showsSettings) { SettingsView() }
        .fullScreenCover(item: $activeSearch) { request in
            SwipeDeckView(
                model: SwipeDeckViewModel(
                    request: request,
                    service: app.places,
                    library: SwiftDataPlaceLibrary(context: modelContext)
                ),
                onShowLibrary: {
                    activeSearch = nil
                    app.selectedTab = .library
                }
            )
        }
        .fullScreenCover(isPresented: $isMapPickerOpen) {
            MapPinPicker(
                start: app.searchCenter ?? .cologne,
                radius: SearchRadius.value(at: radiusIndex),
                onConfirm: { location in
                    app.selectedLocation = location
                    isMapPickerOpen = false
                    closeLocationPanel()
                }
            )
        }
        .alert("Wo soll gesucht werden?", isPresented: $showsLocationHint) {
            Button("Standort wählen") { openLocationPanel() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            if app.location.isDenied {
                Text("SpotSwipe darf deinen Standort nicht verwenden. Wähle oben rechts einen Ort oder erlaube den Zugriff in den Einstellungen.")
            } else {
                Text("Dein Standort ist noch nicht bekannt. Wähle oben rechts einen Ort.")
            }
        }
        .onAppear {
            if app.selectedLocation == nil { app.location.refresh() }
            guard !didApplyDefaultRadius else { return }
            radiusIndex = defaultRadiusIndex
            didApplyDefaultRadius = true
        }
        .onChange(of: defaultRadiusIndex) { _, new in radiusIndex = new }
        #if DEBUG
        .task { await runDemo() }
        #endif
    }

    #if DEBUG
    @State private var didRunDemo = false

    private func runDemo() async {
        guard !didRunDemo else { return }
        didRunDemo = true
        try? await Task.sleep(for: .milliseconds(600))
        switch DemoLaunch.screen {
        case "settings": showsSettings = true
        case "location": openLocationPanel()
        case "map": isMapPickerOpen = true
        default: break
        }
        if let term = DemoLaunch.search {
            query = term
            startSearch()
        }
    }
    #endif

    // MARK: - Teile

    private var topBar: some View {
        HStack {
            GlassIconButton(systemImage: "gearshape", label: "Einstellungen") { showsSettings = true }
            Spacer()
            Button(action: openLocationPanel) {
                HStack(spacing: 6) {
                    Image(systemName: app.selectedLocation == nil ? "location.fill" : "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(app.searchCenterName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityLabel("Standort ändern, aktuell \(app.searchCenterName)")
        }
        .padding(.top, 8)
    }

    private var headline: some View {
        Text("Wonach\nsuchst du?")
            .font(.system(size: headlineSize, weight: .heavy))
            .tracking(-headlineSize * 0.04)
            .lineSpacing(-4)
            .foregroundStyle(Theme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("Café, Pizza, Buchladen …", text: $query)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .focused($isSearchFocused)
                .submitLabel(.go)
                .onSubmit(startSearch)
                .autocorrectionDisabled()
                .accessibilityLabel("Wonach suchst du?")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Theme.fill, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eingabe löschen")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 64)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.06), radius: 15, y: 10)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    ChipButton(title: suggestion, isSelected: trimmedQuery.caseInsensitiveCompare(suggestion) == .orderedSame) {
                        query = suggestion
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    @ViewBuilder
    private var recentRow: some View {
        let recent = RecentSearches.decode(recentStorage).prefix(3)
        if !recent.isEmpty {
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 4)
                Text("Zuletzt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 4)
                ForEach(Array(recent), id: \.self) { term in
                    Button(term) { query = term }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, -8)
        }
    }

    private var goButton: some View {
        Button(action: startSearch) {
            HStack(spacing: 10) {
                Text("Go")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 22, weight: .heavy))
        }
        .buttonStyle(PrimaryButtonStyle(height: 64))
        .disabled(trimmedQuery.isEmpty)
        .opacity(trimmedQuery.isEmpty ? 0.45 : 1)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .accessibilityHint(trimmedQuery.isEmpty ? Text("Gib zuerst ein, wonach du suchst.") : Text(verbatim: ""))
    }

    // MARK: - Aktionen

    private func startSearch() {
        guard !trimmedQuery.isEmpty else { return }
        guard let center = app.searchCenter else {
            showsLocationHint = true
            return
        }
        isSearchFocused = false
        recentStorage = RecentSearches.adding(trimmedQuery, to: recentStorage)
        activeSearch = SearchRequest(
            query: trimmedQuery,
            center: center,
            centerName: app.searchCenterPlaceName,
            radius: SearchRadius.value(at: radiusIndex),
            cardsPerRound: CardsPerRound.options.contains(cardsPerRound) ? cardsPerRound : CardsPerRound.standard,
            onlyOpenNow: onlyOpenNow,
            hideSaved: hideSavedPlaces
        )
    }

    private func openLocationPanel() {
        isSearchFocused = false
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { isLocationPanelOpen = true }
    }

    private func closeLocationPanel() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { isLocationPanelOpen = false }
    }
}
