import SwiftUI

/// Swipe-Karte, Variante A aus dem Design: Foto über die ganze Karte, Infos und Aktionen darüber.
struct PlaceCardView: View {
    let place: Place
    let distance: Double?
    var isActive = true
    /// -1 (ganz nach links gezogen) … 1 (ganz nach rechts).
    var swipeProgress: Double = 0
    var onOpenDetail: () -> Void = {}

    var body: some View {
        PhotoCarousel(photos: place.photos, seed: place.id, isActive: isActive)
            .overlay(alignment: .bottom) { info }
            .overlay(alignment: .topLeading) {
                stamp("MERKEN", color: Theme.accent, angle: -14)
                    .padding(.leading, 22)
                    .padding(.top, 54)
                    .opacity(max(0, swipeProgress))
            }
            .overlay(alignment: .topTrailing) {
                stamp("WEITER", color: Color(hex: 0x111111), angle: 14)
                    .padding(.trailing, 22)
                    .padding(.top, 54)
                    .opacity(max(0, -swipeProgress))
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 25, y: 12)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 10) {
            tags
            Text(place.name)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.9)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            metaRow
            if let reason = place.aiReason {
                Label {
                    Text(reason).lineLimit(2)
                } icon: {
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .accessibilityLabel(Text("KI: \(reason)"))
            }
            CardActions(place: place, style: .onPhoto)
                .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.5), location: 0.36),
                    .init(color: .black.opacity(0.84), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenDetail)
        .accessibilityAction(named: "Details anzeigen", onOpenDetail)
    }

    @ViewBuilder
    private var tags: some View {
        let status = place.openingStatus
        if place.category != nil || status != nil {
            HStack(spacing: 6) {
                if let category = place.category {
                    tag { Text(category) }
                }
                if let status {
                    tag {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(place.isOpenNow == true ? Color(hex: 0x5BE08E) : Color(hex: 0xFF8A70))
                                .frame(width: 7, height: 7)
                            Text(status)
                        }
                    }
                }
            }
        }
    }

    private func tag<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.white.opacity(0.2), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.28)))
    }

    private var metaRow: some View {
        HStack(spacing: 7) {
            if let rating = place.rating {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.star)
                    .font(.system(size: 14))
                Text(Formatters.rating(rating))
                if let count = place.userRatingCount {
                    Text(verbatim: "(\(count))").foregroundStyle(.white.opacity(0.8)).fontWeight(.medium)
                }
            }
            ForEach(Array(metaParts.enumerated()), id: \.offset) { index, part in
                if index > 0 || place.rating != nil {
                    Text(verbatim: "·").foregroundStyle(.white.opacity(0.6))
                }
                Text(part)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var metaParts: [String] {
        [distance.map { Formatters.distance($0) }, place.priceLevel?.symbol].compactMap { $0 }
    }

    private func stamp(_ text: LocalizedStringKey, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .black))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }
}
