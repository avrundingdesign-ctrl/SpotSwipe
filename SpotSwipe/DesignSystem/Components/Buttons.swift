import SwiftUI

/// Runde Glas-Taste (Zurück, Einstellungen, Teilen …).
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var tint: Color = Theme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

/// Große Hauptaktion in Akzentfarbe („Go“, „Hier suchen“, „Zur Bibliothek“).
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.accent, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 15, y: 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Zweitaktion: helle Fläche mit feiner Kante.
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Auswahl-Chip; ausgewählt dunkel gefüllt, sonst hell mit Kante.
struct ChipButton: View {
    let title: String
    var isSelected = false
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.inverseText : Theme.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: height)
                .background(isSelected ? Theme.textPrimary : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Theme.textPrimary : Theme.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Helle Karte mit feiner Kante für Einstellungen, Infos und Öffnungszeiten.
struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.sectionRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.sectionRadius, style: .continuous).strokeBorder(Theme.hairline))
    }
}

struct SectionDivider: View {
    var leading: CGFloat = 16

    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, leading)
    }
}
