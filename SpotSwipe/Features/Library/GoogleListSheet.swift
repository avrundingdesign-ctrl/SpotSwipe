import SwiftData
import SwiftUI

/// Die sichtbaren Orte der Bibliothek als Liste in Google Maps.
///
/// Fehlende Google-Place-IDs werden erst hier nachgeschlagen und am Ort gespeichert. Danach öffnet
/// Google Maps die Auswahl (siehe `GoogleMapsList`); Speichern, Teilen und Einladen laufen dort.
struct GoogleListSheet: View {
    /// In der Reihenfolge der Bibliothek – Suche, Filter und Sortierung zählen.
    let places: [SavedPlace]

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private enum Status {
        case searching
        case ready(URL, count: Int, unknown: Int)
        case failed(String)
    }

    @State private var status = Status.searching

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 28)
            Text("Als Google-Maps-Liste")
                .font(.system(size: 24, weight: .heavy))
                .multilineTextAlignment(.center)

            switch status {
            case .searching:
                ProgressView().padding(.top, 8)
                hint(Text("Suche die Orte bei Google …"))
            case let .ready(url, count, unknown):
                Text(count == 1 ? String(localized: "1 Spot") : String(localized: "\(count) Spots"))
                    .font(.system(size: 17, weight: .semibold))
                if places.count > GoogleMapsList.maxPlaces {
                    hint(Text("Google Maps nimmt höchstens \(GoogleMapsList.maxPlaces) Orte. Mit Suche oder Filter wählst du andere aus."))
                }
                if unknown > 0 {
                    hint(Text("Google kennt \(unknown) davon nicht."))
                }
                Spacer(minLength: 8)
                Button("In Google Maps öffnen") { openURL(url) }
                    .buttonStyle(.primary)
                ShareLink(item: url) {
                    Text("Link teilen")
                }
                .buttonStyle(.secondary)
                hint(Text("In Google Maps kannst du die Liste speichern und mit anderen teilen."))
            case let .failed(message):
                hint(Text(message))
                Spacer(minLength: 8)
                Button("Nochmal versuchen") {
                    Task { await prepare() }
                }
                .buttonStyle(.primary)
                Button("Schließen") { dismiss() }
                    .buttonStyle(.secondary)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .task { await prepare() }
    }

    private func hint(_ text: Text) -> some View {
        text
            .font(.system(size: 15))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Schlägt fehlende IDs in einem Rutsch nach, speichert sie und baut den Link.
    /// Orte, die Google nicht kennt, werden beim nächsten Mal erneut versucht.
    private func prepare() async {
        status = .searching
        let chosen = Array(places.prefix(GoogleMapsList.maxPlaces))
        let missing = chosen.filter { ($0.googlePlaceID ?? "").isEmpty }
        if !missing.isEmpty {
            guard let ids = await app.places.googlePlaceIDs(for: missing.map(\.asPlace)) else {
                status = .failed(String(localized: "Google ist gerade nicht erreichbar. Versuch es später noch einmal."))
                return
            }
            for (place, id) in zip(missing, ids) where id != nil {
                place.googlePlaceID = id
            }
            try? context.save()
        }

        let ids = chosen.compactMap(\.googlePlaceID).filter { !$0.isEmpty }
        guard let url = GoogleMapsList.shortlistURL(placeIDs: ids) else {
            status = .failed(String(localized: "Google kennt keinen dieser Orte."))
            return
        }
        status = .ready(url, count: ids.count, unknown: chosen.count - ids.count)
    }
}
