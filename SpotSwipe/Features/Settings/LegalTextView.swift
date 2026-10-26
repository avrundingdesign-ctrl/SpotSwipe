import SwiftUI

/// Rechtstexte aus `Resources/Legal/*.md` – dieselben Dateien, aus denen
/// `scripts/make_legal_pages.py` die Webseiten auf dem Server erzeugt.
/// Fassungen gibt es auf Deutsch und Englisch; alle anderen Sprachen bekommen Englisch.
enum LegalDocument: String, Identifiable {
    case imprint, privacy

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .imprint: "Impressum"
        case .privacy: "Datenschutz"
        }
    }

    var text: String {
        let language = AppLanguage.code == "de" ? "de" : "en"
        guard let url = Bundle.main.url(forResource: "\(rawValue).\(language)", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}

struct LegalTextView: View {
    let document: LegalDocument

    private enum Block: Hashable {
        case title(String), heading(String), paragraph(String)
    }

    /// Minimales Markdown: „# “ Titel, „## “ Abschnitt, Leerzeile trennt Absätze, Zeilenumbrüche bleiben.
    private var blocks: [Block] {
        document.text.components(separatedBy: "\n\n").compactMap { chunk in
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.hasPrefix("## ") { return .heading(String(trimmed.dropFirst(3))) }
            if trimmed.hasPrefix("# ") { return .title(String(trimmed.dropFirst(2))) }
            return .paragraph(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(blocks, id: \.self) { block in
                    switch block {
                    case .title(let text):
                        Text(verbatim: text)
                            .font(.system(size: 28, weight: .heavy))
                            .accessibilityAddTraits(.isHeader)
                    case .heading(let text):
                        Text(verbatim: text)
                            .font(.system(size: 17, weight: .bold))
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                    case .paragraph(let text):
                        Text(verbatim: text)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .textSelection(.enabled)
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
