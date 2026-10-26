import Foundation

/// Entfernungen, Bewertungen und Öffnungszeiten in der Sprache und dem Zahlenformat des Geräts.
nonisolated enum Formatters {
    /// 650 → "650 m", 1234 → "1,2 km" (de) bzw. "1.2 km" (en), 12 400 → "12 km"
    static func distance(_ meters: Double, locale: Locale = .autoupdatingCurrent) -> String {
        if meters < 1_000 {
            let rounded = max(10, (meters / 10).rounded() * 10)
            return "\(Int(rounded)) m"
        }
        let km = meters / 1_000
        let digits = km < 10 ? 1 : 0
        return km.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " km"
    }

    /// Radius-Werte aus `SearchRadius`: 500 → "500 m", 2000 → "2 km"
    static func radius(_ meters: Double, locale: Locale = .autoupdatingCurrent) -> String {
        if meters < 1_000 { return "\(Int(meters)) m" }
        return (meters / 1_000).formatted(.number.precision(.fractionLength(0...1)).locale(locale)) + " km"
    }

    /// Kurzbeschriftung unter dem Umkreis-Regler: "0,5" … "25 km"
    static func radiusTick(_ meters: Double, isLast: Bool, locale: Locale = .autoupdatingCurrent) -> String {
        let value = (meters / 1_000).formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return isLast ? value + " km" : value
    }

    static func rating(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    static func openingStatus(
        isOpen: Bool?,
        nextClose: Date?,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String? {
        guard let isOpen else { return nil }
        guard isOpen else { return String(localized: "Geschlossen") }
        guard let nextClose else { return String(localized: "Geöffnet") }
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        let time = nextClose.formatted(style)
        return String(localized: "Geöffnet · bis \(time)")
    }

    static func savedDate(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
}

/// Sprache, in der die Oberfläche gerade läuft (de, en, es, fr, tr oder it).
nonisolated enum AppLanguage {
    static var code: String {
        Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) } ?? "de"
    }
}
