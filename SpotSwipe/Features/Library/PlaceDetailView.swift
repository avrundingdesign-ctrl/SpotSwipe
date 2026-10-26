import MapKit
import SwiftData
import SwiftUI

/// Detailansicht für einen Ort, aus der Swipe-Karte (noch nicht gemerkt) oder aus der Bibliothek.
struct PlaceDetailView: View {
    let saved: SavedPlace?

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var place: Place
    @State private var confirmsRemoval = false
    @State private var safariURL: IdentifiableURL?

    /// Schnappschüsse älter als ein Tag werden beim Öffnen aufgefrischt.
    private static let refreshInterval: TimeInterval = 24 * 60 * 60

    init(place: Place) {
        saved = nil
        _place = State(initialValue: place)
    }

    init(saved: SavedPlace) {
        self.saved = saved
        _place = State(initialValue: saved.asPlace)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PhotoCarousel(photos: place.photos, seed: place.id, barsAtBottom: true)
                    .frame(height: 440)
                content
                    .background(
                        Theme.background,
                        in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    )
                    .padding(.top, -32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if saved == nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen", systemImage: "xmark") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: place.shareURL, subject: Text(place.name)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Teilen")
            }
            if saved != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aus Bibliothek entfernen", systemImage: "heart.fill") { confirmsRemoval = true }
                        .tint(Theme.accent)
                }
            }
        }
        .confirmationDialog("„\(place.name)“ aus der Bibliothek entfernen?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive, action: remove)
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
        .task { await refreshIfNeeded() }
    }

    // MARK: - Inhalt

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                if let category = place.category {
                    Text(category)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Theme.fill, in: Capsule())
                }
                Spacer()
                if let saved {
                    Text("Gemerkt am \(Formatters.savedDate(saved.savedAt))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1.2)
                    .accessibilityAddTraits(.isHeader)
                metaRow
                if let status = place.openingStatus {
                    HStack(spacing: 7) {
                        Circle().frame(width: 7, height: 7)
                        Text(status)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(place.isOpenNow == true ? Theme.success : Theme.destructive)
                }
            }

            CardActions(place: place, style: .tiles)

            infoCard
            if !place.weekdayHours.isEmpty { hoursCard }
            mapSnippet

            if let saved {
                Text("Gemerkt bei der Suche „\(saved.searchTerm)“.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
                Button(role: .destructive) {
                    confirmsRemoval = true
                } label: {
                    Label("Aus Bibliothek entfernen", systemImage: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.destructive)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                }
                .buttonStyle(.plain)
            }

            Text(app.places.attribution)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    private var metaRow: some View {
        let parts = [
            place.userRatingCount.map { "(\($0) Bewertungen)" },
            place.priceLevel?.symbol,
            app.location.currentPoint.map { Formatters.distance(place.distance(from: $0)) }
        ].compactMap { $0 }
        return HStack(spacing: 6) {
            if let rating = place.rating {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xF2A60C))
                Text(Formatters.rating(rating)).fontWeight(.bold)
            }
            Text(parts.joined(separator: " · "))
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.system(size: 15))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var infoCard: some View {
        SectionCard {
            if let address = place.address {
                Button { openURL(place.routeURL) } label: {
                    infoRow(systemImage: "mappin", title: address, chevron: false)
                }
                .buttonStyle(.plain)
            }
            if let phone = place.phoneNumber, let url = place.phoneURL {
                SectionDivider(leading: 50)
                Button { openURL(url) } label: {
                    infoRow(systemImage: "phone", title: phone, chevron: false)
                }
                .buttonStyle(.plain)
            }
            if let website = place.websiteURL {
                SectionDivider(leading: 50)
                Button { safariURL = IdentifiableURL(url: website) } label: {
                    infoRow(systemImage: "globe", title: "Website öffnen", chevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoRow(systemImage: String, title: String, chevron: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private var hoursCard: some View {
        // Google liefert Montag zuerst; Calendar zählt Sonntag = 1.
        let todayIndex = (Calendar.current.component(.weekday, from: .now) + 5) % 7
        return VStack(alignment: .leading, spacing: 10) {
            Text("Öffnungszeiten")
                .font(.system(size: 17, weight: .bold))
            ForEach(Array(place.weekdayHours.enumerated()), id: \.offset) { index, line in
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                HStack {
                    Text(index == todayIndex ? "\(parts.first ?? "") · heute" : parts.first ?? line)
                    Spacer()
                    Text(parts.count > 1 ? parts[1] : "")
                }
                .font(.system(size: 15, weight: index == todayIndex ? .bold : .regular))
                .foregroundStyle(index == todayIndex ? Theme.textPrimary : Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.sectionRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.sectionRadius, style: .continuous).strokeBorder(Theme.hairline))
    }

    private var mapSnippet: some View {
        Map(
            initialPosition: .region(MKCoordinateRegion(center: place.location.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)),
            interactionModes: []
        ) {
            Marker(place.name, coordinate: place.location.coordinate)
                .tint(Theme.accent)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Theme.sectionRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Button("In Karten öffnen") { openURL(place.appleMapsURL) }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .glassEffect(.regular.interactive(), in: Capsule())
                .padding(10)
        }
    }

    // MARK: - Aktionen

    /// Holt Fotos, Bewertung und Öffnungsstatus nach: für gemerkte Orte höchstens einmal am Tag,
    /// für Karten aus der Runde nur, wenn sie noch keine Fotos hatten.
    private func refreshIfNeeded() async {
        if let saved {
            guard Date.now.timeIntervalSince(saved.snapshotFetchedAt) > Self.refreshInterval else { return }
        } else {
            guard place.photos.isEmpty else { return }
        }
        guard let extras = await app.places.extras(for: place) else { return }
        place = place.merging(extras)
        if let saved {
            saved.update(from: place)
            try? context.save()
        }
    }

    private func remove() {
        guard let saved else { return }
        context.delete(saved)
        try? context.save()
        dismiss()
    }
}
