import SwiftUI

/// Kurzes Intro beim ersten Start: suchen, wischen, merken – und am Ende der Standort.
struct IntroView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var app
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("Überspringen") { withAnimation(.snappy) { page = pageCount - 1 } }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                IntroPage(
                    title: "Wonach suchst du?",
                    text: "Café, Pizza, ein Park zum Lesen: Tipp ein, was du suchst, und wie weit du laufen willst."
                ) { SearchIllustration() }
                    .tag(0)
                IntroPage(
                    title: "Wisch dich durch",
                    text: "Rechts heißt merken, links heißt weiter. Tipp aufs Foto für mehr Bilder."
                ) { SwipeIllustration() }
                    .tag(1)
                IntroPage(
                    title: "Alles an einem Ort",
                    text: "Gemerkte Spots landen in deiner Bibliothek – mit Route, Website und Telefonnummer."
                ) { LibraryIllustration() }
                    .tag(2)
                IntroPage(
                    title: "Was ist in deiner Nähe?",
                    text: "Mit deinem Standort findet SpotSwipe Orte um dich herum. Du kannst auch jederzeit einen anderen Ort wählen."
                ) { LocationIllustration() }
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #if DEBUG
            .onAppear { page = min(DemoLaunch.introPage, pageCount - 1) }
            #endif

            pageIndicator
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                if page < pageCount - 1 {
                    Button("Weiter") { withAnimation(.snappy) { page += 1 } }
                        .buttonStyle(.primary)
                } else {
                    Button("Standort erlauben") {
                        app.location.start()
                        onFinish()
                    }
                    .buttonStyle(.primary)
                    Button("Ohne Standort starten", action: onFinish)
                        .buttonStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(height: 140, alignment: .top)
        }
        .background(Theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: page)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.accent : Theme.hairline)
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityElement()
        .accessibilityLabel(Text("Seite \(page + 1) von \(pageCount)"))
    }
}

private struct IntroPage<Illustration: View>: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder var illustration: Illustration

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-1)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Illustrationen (aus den Bausteinen des Designs)

private struct PhotoTile: View {
    let seed: String
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat = 22

    var body: some View {
        PhotoPlaceholder(seed: seed)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct SearchIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                Text("Café", comment: "Beispiel-Suchbegriff im Intro")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(width: 280, height: 58)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.06), radius: 15, y: 10)

            HStack(spacing: 8) {
                chip(String(localized: "Café", comment: "Suchvorschlag"), selected: true)
                chip(String(localized: "Brunch", comment: "Suchvorschlag"), selected: false)
                chip(String(localized: "Park", comment: "Suchvorschlag"), selected: false)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Umkreis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(Formatters.radius(2_000))
                        .font(.system(size: 22, weight: .heavy))
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill).frame(height: 6)
                    Capsule().fill(Theme.accent).frame(width: 96, height: 6)
                    Circle().fill(.white).frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        .offset(x: 84)
                }
            }
            .padding(16)
            .frame(width: 280)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func chip(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? Theme.inverseText : Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(selected ? Theme.textPrimary : Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Theme.textPrimary : Theme.hairline))
    }
}

private struct SwipeIllustration: View {
    var body: some View {
        ZStack {
            PhotoTile(seed: "intro-b", width: 200, height: 270, radius: 28)
                .scaleEffect(0.92, anchor: .bottom)
                .offset(y: 14)
            PhotoTile(seed: "intro-a", width: 200, height: 270, radius: 28)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(.white.opacity(0.9)).frame(width: 110, height: 12)
                        Capsule().fill(.white.opacity(0.6)).frame(width: 70, height: 8)
                    }
                    .padding(16)
                }
                .overlay(alignment: .topLeading) {
                    Text("MERKEN")
                        .font(.system(size: 18, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2.5))
                        .rotationEffect(.degrees(-14))
                        .padding(18)
                }
                .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
                .phaseAnimator([0.0, 1.0]) { card, phase in
                    card
                        .rotationEffect(.degrees(phase * 7), anchor: .bottom)
                        .offset(x: phase * 26)
                } animation: { _ in .easeInOut(duration: 1.4) }

            HStack(spacing: 120) {
                circleButton("xmark", fill: Theme.surface, tint: Theme.textPrimary)
                circleButton("heart.fill", fill: Theme.accent, tint: .white)
            }
            .offset(y: 160)
        }
        .offset(y: -20)
    }

    private func circleButton(_ symbol: String, fill: Color, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 54, height: 54)
            .background(fill, in: Circle())
            .overlay(Circle().strokeBorder(Theme.hairline.opacity(fill == Theme.surface ? 1 : 0)))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 8)
    }
}

private struct LibraryIllustration: View {
    var body: some View {
        let columns = [GridItem(.fixed(118), spacing: 12), GridItem(.fixed(118), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(["intro-c", "intro-d", "intro-e", "intro-f"], id: \.self) { seed in
                PhotoTile(seed: seed, width: 118, height: 132)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Theme.accent, in: Circle())
                            .padding(8)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            Label("iCloud", systemImage: "icloud.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .offset(y: 50)
        }
        .offset(y: -20)
    }
}

private struct LocationIllustration: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(Theme.accent.opacity(0.25 - Double(ring) * 0.07), lineWidth: 2)
                    .frame(width: 130 + CGFloat(ring) * 70, height: 130 + CGFloat(ring) * 70)
            }
            Circle()
                .fill(Theme.accent)
                .frame(width: 110, height: 110)
                .shadow(color: Theme.accent.opacity(0.35), radius: 24, y: 12)
            Image(systemName: "location.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .phaseAnimator([1.0, 1.06]) { content, scale in
            content.scaleEffect(scale)
        } animation: { _ in .easeInOut(duration: 1.6) }
    }
}
