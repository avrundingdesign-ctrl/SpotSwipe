import MapKit
import SwiftUI

/// Fährt aus dem Standort-Chip heraus: Adresse eintippen, aktueller Standort oder Nadel auf der Karte.
struct LocationPanel: View {
    var onClose: () -> Void
    var onPickOnMap: () -> Void

    @Environment(AppModel.self) private var app
    @State private var completer = AddressCompleter()
    @State private var resolvingTitle: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Standort")
                    .font(.system(size: 22, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .frame(width: 32, height: 32)
                        .background(Theme.fill, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Schließen")
            }
            .padding(.leading, 6)

            searchField

            if !completer.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(completer.results, id: \.self) { completion in
                        Button {
                            select(completion)
                        } label: {
                            row(
                                icon: Image(systemName: "mappin"),
                                iconBackground: Theme.background,
                                iconColor: Theme.textSecondary,
                                title: completion.title,
                                subtitle: completion.subtitle
                            ) {
                                if resolvingTitle == completion.title { ProgressView() }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                SectionDivider(leading: 6)
            }

            VStack(spacing: 0) {
                Button {
                    app.selectedLocation = nil
                    app.location.start()
                    onClose()
                } label: {
                    row(
                        icon: Image(systemName: "location.fill"),
                        iconBackground: Theme.accent,
                        iconColor: .white,
                        title: String(localized: "Aktueller Standort"),
                        subtitle: currentLocationSubtitle
                    ) {
                        if app.selectedLocation == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .accessibilityLabel("Ausgewählt")
                        }
                    }
                }
                .buttonStyle(.plain)

                Button(action: onPickOnMap) {
                    row(
                        icon: Image(systemName: "map"),
                        iconBackground: Theme.background,
                        iconColor: Theme.textPrimary,
                        title: String(localized: "Auf Karte wählen"),
                        subtitle: String(localized: "Nadel setzen, wo du suchen willst")
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 30, y: 24)
        .onAppear {
            completer.bias(to: app.searchCenter)
            isFieldFocused = true
        }
    }

    private var currentLocationSubtitle: String {
        if app.location.isDenied { return String(localized: "Zugriff in den iOS-Einstellungen erlauben") }
        return app.location.currentPlaceName ?? String(localized: "Wird ermittelt …")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("Adresse, Ort oder PLZ", text: $completer.query)
                .font(.system(size: 17, weight: .semibold))
                .focused($isFieldFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    if let first = completer.results.first { select(first) }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isFieldFocused ? Theme.accent : Theme.hairline, lineWidth: isFieldFocused ? 2 : 1)
        )
    }

    private func row<Trailing: View>(
        icon: Image,
        iconBackground: Color,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            icon
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconBackground, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        resolvingTitle = completion.title
        Task {
            let location = await completer.resolve(completion)
            resolvingTitle = nil
            guard let location else { return }
            app.selectedLocation = location
            onClose()
        }
    }
}
