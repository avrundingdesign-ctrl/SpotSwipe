import SwiftData
import SwiftUI

/// Alle gemerkten Orte als 2-spaltiges Raster, filterbar nach Suchbegriff.
struct LibraryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPlace.savedAt, order: .reverse) private var saved: [SavedPlace]

    @State private var searchText = ""
    @State private var termFilter: String?
    @State private var sortByDistance = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if saved.isEmpty {
                    emptyState
                } else {
                    searchField.padding(.top, 16)
                    filterChips.padding(.top, 12)
                    grid.padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SavedPlace.self) { place in
            PlaceDetailView(saved: place)
        }
        #if DEBUG
        .navigationDestination(item: $demoDetail) { PlaceDetailView(saved: $0) }
        .task {
            guard DemoLaunch.screen == "detail", DemoLaunch.tab == "library" else { return }
            try? await Task.sleep(for: .milliseconds(800))
            demoDetail = saved.first
        }
        #endif
    }

    #if DEBUG
    @State private var demoDetail: SavedPlace?
    #endif

    // MARK: - Teile

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Bibliothek")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1.2)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !saved.isEmpty {
                    Menu {
                        Picker("Sortierung", selection: $sortByDistance) {
                            Text("Neueste zuerst").tag(false)
                            Text("Nächste zuerst").tag(true)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortByDistance ? "Nächste" : "Neueste")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                    .accessibilityLabel("Sortieren")
                }
            }
            .frame(minHeight: 44)
            HStack(spacing: 6) {
                Image(systemName: AppConfig.isCloudSyncEnabled ? "icloud" : "iphone")
                Text(statusLine)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.top, 8)
    }

    private var statusLine: String {
        let count = saved.count == 1 ? "1 Spot" : "\(saved.count) Spots"
        return count + (AppConfig.isCloudSyncEnabled ? " · mit iCloud synchronisiert" : " · auf diesem iPhone")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("In Bibliothek suchen", text: $searchText)
                .font(.system(size: 16))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
    }

    private var terms: [(term: String, count: Int)] {
        Dictionary(grouping: saved, by: \.searchTerm)
            .map { (term: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.term < $1.term }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChipButton(title: "Alle \(saved.count)", isSelected: termFilter == nil, height: 40) {
                    termFilter = nil
                }
                ForEach(terms, id: \.term) { item in
                    ChipButton(title: "\(item.term) \(item.count)", isSelected: termFilter == item.term, height: 40) {
                        termFilter = termFilter == item.term ? nil : item.term
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    private var visiblePlaces: [SavedPlace] {
        let needle = searchText.trimmingCharacters(in: .whitespaces)
        var places = saved.filter { place in
            (termFilter == nil || place.searchTerm == termFilter)
                && (needle.isEmpty
                    || place.name.localizedStandardContains(needle)
                    || (place.category ?? "").localizedStandardContains(needle)
                    || (place.address ?? "").localizedStandardContains(needle))
        }
        if sortByDistance, let here = app.location.currentPoint ?? app.searchCenter {
            places.sort { $0.location.distance(to: here) < $1.location.distance(to: here) }
        }
        return places
    }

    @ViewBuilder
    private var grid: some View {
        let places = visiblePlaces
        if places.isEmpty {
            Text("Keine Treffer für „\(searchText)“.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(places) { place in
                    NavigationLink(value: place) {
                        LibraryCard(place: place, distance: app.location.currentPoint.map { place.location.distance(to: $0) })
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        ShareLink(item: place.asPlace.shareURL) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                        Link(destination: place.asPlace.routeURL) {
                            Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                        }
                        Button(role: .destructive) {
                            withAnimation { context.delete(place) }
                            try? context.save()
                        } label: {
                            Label("Aus Bibliothek entfernen", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 90)
            Text("Noch nichts gemerkt")
                .font(.system(size: 24, weight: .heavy))
            Text("Wisch eine Karte nach rechts, dann landet der Ort hier.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Entdecken") { app.selectedTab = .discover }
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .frame(maxWidth: 220)
                .padding(.top, 8)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
    }
}

private struct LibraryCard: View {
    let place: SavedPlace
    let distance: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlacePhotoView(photo: place.asPlace.photos.first, seed: place.placeID)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let distance {
                        Text(Formatters.distance(distance))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(.black.opacity(0.38), in: Capsule())
                            .padding(8)
                    }
                }
            Text(place.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.top, 8)
            Text(place.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension GeoPoint {
    func distance(to other: GeoPoint) -> Double {
        GeoMath.distance(from: self, to: other)
    }
}
