import SwiftUI

/// Ende der Runde. Bewusst ohne „Mehr laden“: eine Suche, eine Runde.
struct RoundFinishedView: View {
    let liked: [Place]
    let total: Int
    var onShowLibrary: () -> Void
    var onNewSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GlassIconButton(systemImage: "xmark", label: "Schließen", action: onNewSearch)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
            fan
                .frame(height: 210)
            VStack(spacing: 10) {
                Text("Runde geschafft")
                    .font(.system(size: 36, weight: .heavy))
                    .tracking(-1.2)
                Text(message)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            Spacer()

            VStack(spacing: 10) {
                if liked.isEmpty {
                    Button("Neue Suche", action: onNewSearch).buttonStyle(.primary)
                    Button("Zur Bibliothek", action: onShowLibrary).buttonStyle(.secondary)
                } else {
                    Button("Zur Bibliothek", action: onShowLibrary).buttonStyle(.primary)
                    Button("Neue Suche", action: onNewSearch).buttonStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private var message: String {
        switch liked.count {
        case 0: String(localized: "Diesmal war nichts dabei. Probier einen anderen Begriff oder einen größeren Umkreis.")
        case 1: String(localized: "Du hast 1 von \(total) Spots gemerkt. Er wartet in deiner Bibliothek.")
        default: String(localized: "Du hast \(liked.count) von \(total) Spots gemerkt. Sie warten in deiner Bibliothek.")
        }
    }

    /// Bis zu vier gemerkte Orte als aufgefächerte Fotos, darunter das Herz.
    private var fan: some View {
        let shown = Array(liked.prefix(4))
        return ZStack(alignment: .bottom) {
            ZStack {
                if shown.isEmpty {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.fill)
                        .frame(width: 104, height: 136)
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, place in
                    // -1,5 … 1,5 bei vier Fotos: symmetrisch um die Mitte gefächert
                    let centered = Double(index) - Double(shown.count - 1) / 2
                    PlacePhotoView(photo: place.photos.first, seed: place.id)
                        .frame(width: 104, height: 136)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.surface, lineWidth: 3))
                        .shadow(color: .black.opacity(0.14), radius: 14, y: 12)
                        .rotationEffect(.degrees(centered * 9))
                        .offset(x: centered * 56, y: abs(centered) * 14)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Image(systemName: liked.isEmpty ? "heart" : "heart.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(liked.isEmpty ? Theme.textSecondary : Theme.accent, in: Circle())
                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 4))
        }
        .accessibilityHidden(true)
    }
}
