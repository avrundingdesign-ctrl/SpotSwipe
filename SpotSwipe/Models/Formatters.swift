import Foundation

/// Deutsche Darstellung von Entfernungen, Bewertungen und Öffnungszeiten.
nonisolated enum Formatters {
    static let locale = Locale(identifier: "de_DE")

    /// 650 → "650 m", 1234 → "1,2 km", 12 400 → "12 km"
    static func distance(_ meters: Double) -> String {
        if meters < 1_000 {
            let rounded = max(10, (meters / 10).rounded() * 10)
            return "\(Int(rounded)) m"
        }
        let km = meters / 1_000
        let digits = km < 10 ? 1 : 0
        return km.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " km"
    }

    /// Radius-Werte aus `SearchRadius`: 500 → "500 m", 2000 → "2 km"
    static func radius(_ meters: Double) -> String {
        if meters < 1_000 { return "\(Int(meters)) m" }
        return (meters / 1_000).formatted(.number.precision(.fractionLength(0...1)).locale(locale)) + " km"
    }

    static func rating(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    static func openingStatus(isOpen: Bool?, nextClose: Date?, calendar: Calendar = .current) -> String? {
        guard let isOpen else { return nil }
        guard isOpen else { return "Geschlossen" }
        guard let nextClose else { return "Geöffnet" }
        let parts = calendar.dateComponents([.hour, .minute], from: nextClose)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let time = minute == 0 ? "\(hour) Uhr" : String(format: "%d:%02d Uhr", hour, minute)
        return "Geöffnet · bis \(time)"
    }

    static func savedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
}
