import SwiftUI

/// Vollbild-Swipe-Runde: Kartenstapel, ✕ / ↺ / ♥ und am Ende „Runde geschafft“.
struct SwipeDeckView: View {
    @State private var model: SwipeDeckViewModel
    var onShowLibrary: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var pastThreshold = false
    @State private var detailPlace: Place?

    private let threshold: CGFloat = 120

    init(model: SwipeDeckViewModel, onShowLibrary: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onShowLibrary = onShowLibrary
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch model.phase {
            case .loading:
                VStack(spacing: 0) {
                    topBar
                    loadingCard
                }
            case .swiping:
                VStack(spacing: 0) {
                    topBar
                    deck
                    Text(app.places.attribution)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 10)
                    controls
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
            case .finished:
                RoundFinishedView(
                    liked: model.liked,
                    total: model.deck.count,
                    onShowLibrary: onShowLibrary,
                    onNewSearch: { dismiss() }
                )
            case .empty:
                VStack(spacing: 0) {
                    topBar
                    emptyState
                }
            case .failed(let message):
                VStack(spacing: 0) {
                    topBar
                    errorState(message)
                }
            }
        }
        .task {
            if model.deck.isEmpty, model.phase == .loading { await model.load() }
            #if DEBUG
            runDemo()
            #endif
        }
        .sheet(item: $detailPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pastThreshold) { _, isPast in isPast }
        .sensoryFeedback(.success, trigger: model.liked.count) { old, new in new > old }
    }

    #if DEBUG
    private func runDemo() {
        switch DemoLaunch.screen {
        case "finished":
            for index in model.deck.indices { model.decide(index < 4 ? .like : .skip) }
        case "detail":
            detailPlace = model.current
        case "drag":
            dragOffset = CGSize(width: 80, height: 6)
        default:
            break
        }
    }
    #endif

    // MARK: - Kopfzeile

    private var topBar: some View {
        HStack(spacing: 12) {
            GlassIconButton(systemImage: "chevron.left", label: "Zurück zur Suche") { dismiss() }
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text(model.request.query)
                    .font(.system(size: 17, weight: .heavy))
                    .lineLimit(1)
                Text("\(Formatters.radius(model.request.radius)) um \(model.request.centerName ?? "dich")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(model.phase == .swiping ? model.progressText : "–")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 64, minHeight: 44)
                .padding(.horizontal, 6)
                .glassEffect(.regular, in: Capsule())
                .accessibilityLabel(model.phase == .swiping ? "Karte \(model.progressText.replacingOccurrences(of: " / ", with: " von "))" : "")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Kartenstapel

    private var deck: some View {
        let visible = Array(model.remaining.prefix(2).enumerated())
        return ZStack {
            ForEach(visible.reversed(), id: \.element.id) { index, place in
                let isTop = index == 0
                PlaceCardView(
                    place: place,
                    distance: place.distance(from: model.request.center),
                    isActive: isTop,
                    swipeProgress: isTop ? Double(dragOffset.width / threshold) : 0,
                    onOpenDetail: { detailPlace = place }
                )
                .scaleEffect(isTop ? 1 : 0.93, anchor: .bottom)
                .offset(y: isTop ? 0 : 16)
                .offset(isTop ? dragOffset : .zero)
                .rotationEffect(.degrees(isTop ? Double(dragOffset.width / 18) : 0), anchor: .bottom)
                .gesture(dragGesture, isEnabled: isTop && !isAnimatingOut)
                .allowsHitTesting(isTop)
                .zIndex(isTop ? 1 : 0)
                .accessibilityAction(named: "Merken") { commit(.like) }
                .accessibilityAction(named: "Weiter") { commit(.skip) }
                .transition(.asymmetric(insertion: .scale(scale: 0.93, anchor: .bottom).combined(with: .opacity), removal: .identity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16) // Platz für die versetzte Karte dahinter
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                let isPast = abs(value.translation.width) > threshold
                if isPast != pastThreshold { pastThreshold = isPast }
            }
            .onEnded { value in
                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if width > threshold || predicted > threshold * 2.5 {
                    commit(.like)
                } else if width < -threshold || predicted < -threshold * 2.5 {
                    commit(.skip)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragOffset = .zero }
                    pastThreshold = false
                }
            }
    }

    private func commit(_ decision: SwipeDeckViewModel.Decision) {
        guard !isAnimatingOut, model.current != nil else { return }
        isAnimatingOut = true
        let direction: CGFloat = decision == .like ? 1 : -1
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: direction * 650, height: dragOffset.height + 60)
        } completion: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                model.decide(decision)
                dragOffset = .zero
            }
            pastThreshold = false
            isAnimatingOut = false
        }
    }

    // MARK: - ✕ ↺ ♥

    private var controls: some View {
        HStack(spacing: 22) {
            Button { commit(.skip) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 68, height: 68)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 10)
            }
            .accessibilityLabel("Weiter, nicht merken")

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { model.undo() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 10)
            }
            .disabled(!model.canUndo)
            .opacity(model.canUndo ? 1 : 0.45)
            .accessibilityLabel("Letzte Entscheidung rückgängig")

            Button { commit(.like) } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Theme.accent, in: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 13, y: 12)
            }
            .accessibilityLabel("Merken")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zustände

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(Theme.fill)
            .overlay {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("Suche „\(model.request.query)“ in der Nähe …")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 120)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Nichts gefunden")
                .font(.system(size: 28, weight: .heavy))
            Text(emptyMessage)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            if model.request.onlyOpenNow {
                Button("Auch geschlossene Orte zeigen") {
                    Task { await model.retryIncludingClosed() }
                }
                .buttonStyle(.primary)
            }
            Button("Neue Suche") { dismiss() }
                .buttonStyle(.secondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var emptyMessage: String {
        var text = "Im Umkreis von \(Formatters.radius(model.request.radius)) gibt es keine Treffer für „\(model.request.query)“."
        if model.request.onlyOpenNow { text += " Gerade sind nur geöffnete Orte eingeschaltet." }
        if model.request.hideSaved { text += " Bereits gemerkte Orte sind ausgeblendet." }
        return text
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Das hat nicht geklappt")
                .font(.system(size: 28, weight: .heavy))
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Nochmal versuchen") {
                Task { await model.load() }
            }
            .buttonStyle(.primary)
            Button("Neue Suche") { dismiss() }
                .buttonStyle(.secondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
