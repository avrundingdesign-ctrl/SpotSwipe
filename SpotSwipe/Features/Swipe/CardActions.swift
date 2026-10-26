import SafariServices
import SwiftUI

/// Teilen, Website, Anrufen, Route – auf der Karte (Glas über dem Foto) und in der Detailansicht (helle Kacheln).
struct CardActions: View {
    enum Style {
        case onPhoto, tiles
    }

    let place: Place
    var style: Style = .onPhoto

    @Environment(\.openURL) private var openURL
    @State private var safariURL: IdentifiableURL?

    var body: some View {
        HStack(spacing: 8) {
            ShareLink(item: place.shareURL, subject: Text(place.name), message: Text("\(place.name) – gefunden mit SpotSwipe")) {
                tileLabel("Teilen", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)

            actionButton("Website", systemImage: "globe", enabled: place.websiteURL != nil) {
                safariURL = place.websiteURL.map(IdentifiableURL.init)
            }
            actionButton("Anrufen", systemImage: "phone", enabled: place.phoneURL != nil) {
                if let url = place.phoneURL { openURL(url) }
            }
            actionButton("Route", systemImage: "arrow.triangle.turn.up.right.diamond", enabled: true) {
                openURL(place.routeURL)
            }
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
    }

    private func actionButton(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tileLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    @ViewBuilder
    private func tileLabel(_ title: String, systemImage: String) -> some View {
        let label = VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: style == .onPhoto ? 58 : 64)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        switch style {
        case .onPhoto:
            // Kein Liquid Glass: Die Karte wird beim Ziehen gedreht, und Glas verzerrt sich dabei sichtbar.
            label
                .foregroundStyle(.white)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.24)))
        case .tiles:
            label
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
        }
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}

/// In-App-Safari für Websites, damit man nach dem Lesen direkt weiterswipen kann.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
