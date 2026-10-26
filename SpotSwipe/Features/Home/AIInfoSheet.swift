import SwiftUI

/// Erscheint beim ersten Einschalten der KI-Suche: was sie tut, was sie kostet (Zeit), wohin Daten gehen.
struct AIInfoSheet: View {
    var onEnable: () -> Void
    var onCancel: () -> Void

    @State private var showsPrivacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Theme.accent, in: Circle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("KI-Suche")
                        .font(.system(size: 28, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text("Beschreib einfach, was du suchst – etwa „ruhiges Café zum Arbeiten“. Die KI versteht deinen Wunsch, sucht passende Orte und sortiert sie danach.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                infoRow(systemImage: "clock") {
                    Text("Die Suche dauert dadurch etwas länger, die Treffer passen aber besser.")
                }
                infoRow(systemImage: "lock") {
                    Text("Claude (Anthropic) bekommt deinen Suchwunsch und die Namen der gefundenen Orte – nicht deinen Standort. Ist Claude nicht erreichbar, übernimmt Apple Intelligence auf dem iPhone. Umstellen kannst du das in den Einstellungen.")
                }

                Button("Datenschutzerklärung lesen") { showsPrivacy = true }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(24)
        }
        // Die Entscheidung muss auch in halber Höhe sichtbar sein.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("KI-Suche einschalten", action: onEnable)
                    .buttonStyle(.primary)
                Button("Lieber nicht", action: onCancel)
                    .buttonStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Theme.background)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showsPrivacy) {
            NavigationStack { LegalTextView(document: .privacy) }
        }
    }

    private func infoRow<Content: View>(systemImage: String, @ViewBuilder text: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            text()
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
    }
}
