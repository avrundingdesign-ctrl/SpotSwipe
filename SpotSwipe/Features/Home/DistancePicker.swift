import SwiftUI

/// Umkreis-Karte auf der Startseite: großer Wert, Slider mit Rastpunkten, Beschriftung darunter.
struct DistancePicker: View {
    @Binding var index: Int

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Umkreis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                valueLabel
            }
            Slider(
                value: Binding(
                    get: { Double(index) },
                    set: { index = Int($0.rounded()) }
                ),
                in: 0...Double(SearchRadius.options.count - 1),
                step: 1
            )
            .tint(Theme.accent)
            .accessibilityLabel("Umkreis")
            .accessibilityValue(Formatters.radius(SearchRadius.value(at: index)))

            HStack {
                ForEach(SearchRadius.options.indices, id: \.self) { i in
                    if i > 0 { Spacer(minLength: 0) }
                    Text(Formatters.radiusTick(SearchRadius.options[i], isLast: i == SearchRadius.options.count - 1))
                        .foregroundStyle(i == index ? Theme.textPrimary : Theme.textSecondary)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline))
        .sensoryFeedback(.selection, trigger: index)
    }

    private var valueLabel: some View {
        let meters = SearchRadius.value(at: index)
        let number = meters < 1_000 ? "\(Int(meters))" : Formatters.radius(meters).replacingOccurrences(of: " km", with: "")
        let unit = meters < 1_000 ? "m" : "km"
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(number)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.9)
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundStyle(Theme.textPrimary)
        .animation(.snappy, value: index)
    }
}
