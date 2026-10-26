import SwiftUI

/// Foto-Karussell wie bei Stories: links/rechts tippen wechselt das Foto, Balken zeigen die Position.
/// Kein Wischen, weil horizontales Wischen auf der Karte „Merken“/„Weiter“ bedeutet.
struct PhotoCarousel: View {
    let photos: [PlacePhoto]
    let seed: String
    /// Nur die oberste Karte lädt Folgefotos vor (spart Google-Kosten).
    var isActive = true
    var barsAtBottom = false

    @Environment(AppModel.self) private var app
    @State private var index = 0

    private var current: PlacePhoto? {
        photos.indices.contains(index) ? photos[index] : nil
    }

    var body: some View {
        PlacePhotoView(photo: current, seed: seed)
            .overlay {
                if photos.count > 1 { tapZones }
            }
            .overlay(alignment: barsAtBottom ? .bottom : .top) {
                if photos.count > 1 {
                    segmentBars
                        .padding(.horizontal, 14)
                        .padding(barsAtBottom ? .bottom : .top, barsAtBottom ? 48 : 12)
                }
            }
            .overlay(alignment: barsAtBottom ? .bottomTrailing : .topTrailing) {
                if let author = current?.authorName {
                    authorLabel(author)
                        .padding(.trailing, 14)
                        .padding(barsAtBottom ? .bottom : .top, barsAtBottom ? 62 : 24)
                }
            }
            .task(id: "\(isActive)-\(index)") { await prefetchNext() }
    }

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { step(-1) }
                .accessibilityLabel("Vorheriges Foto")
                .accessibilityAddTraits(.isButton)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { step(1) }
                .accessibilityLabel("Nächstes Foto")
                .accessibilityAddTraits(.isButton)
        }
    }

    private var segmentBars: some View {
        HStack(spacing: 4) {
            ForEach(photos.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i <= index ? 0.95 : 0.4))
                    .frame(height: 3)
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 2)
        .accessibilityHidden(true)
    }

    private func authorLabel(_ author: String) -> some View {
        Text("Foto: \(author)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard photos.indices.contains(next) else { return }
        index = next
    }

    private func prefetchNext() async {
        guard isActive, photos.indices.contains(index + 1) else { return }
        _ = await PhotoCache.shared.image(for: photos[index + 1], using: app.places)
    }
}
