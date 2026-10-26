import Foundation

/// Letzte Suchbegriffe, neueste zuerst, als Zeilen in einem `@AppStorage`-String.
nonisolated enum RecentSearches {
    static let limit = 8

    static func decode(_ stored: String) -> [String] {
        stored.split(separator: "\n").map(String.init)
    }

    static func adding(_ term: String, to stored: String) -> String {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return stored }
        var terms = decode(stored).filter { $0.caseInsensitiveCompare(cleaned) != .orderedSame }
        terms.insert(cleaned, at: 0)
        return terms.prefix(limit).joined(separator: "\n")
    }
}
