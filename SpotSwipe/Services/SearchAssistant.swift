import Foundation
import FoundationModels

/// Was die KI aus dem Suchwunsch macht: Suchbegriffe für Apple Karten plus die
/// Kriterien jenseits der Ortsart ("ruhig, mit WLAN").
nonisolated struct AIQueryPlan: Hashable, Sendable {
    var queries: [String]
    var criteria: String
}

/// Ein von der KI gewählter Ort mit Begründung: entweder aus der übergebenen Kandidatenliste (`index`)
/// oder ein Ort, den die KI selbst kennt (`name`) – den sucht die App dann in Apple Karten.
nonisolated struct AIPick: Hashable, Sendable {
    var index: Int?
    var name: String?
    var reason: String?

    init(index: Int, reason: String?) {
        self.index = index
        self.reason = reason
    }

    init(suggestedName name: String, reason: String?) {
        self.name = name
        self.reason = reason
    }
}

nonisolated enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case claude, apple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: "Claude"
        case .apple: "Apple Intelligence"
        }
    }
}

/// KI-Unterstützung für die Suche. Jede Methode liefert `nil`, wenn nichts zu bekommen ist –
/// die Suche läuft dann ganz normal ohne KI weiter.
protocol SearchAssistant: AnyObject {
    /// Wer zuletzt erfolgreich geantwortet hat (für die Quellenzeile).
    var lastProvider: AIProvider? { get }
    /// Orte, die die KI selbst kennt (nur Namen, `AIPick.name`) – der Normalfall mit Claude.
    /// `nil`: kann oder will nicht empfehlen, dann gilt der Weg über `plan` und `rank`.
    /// Leer: hat geantwortet, kennt aber nichts Passendes.
    func recommend(_ wish: String, near center: GeoPoint, radius: Double, limit: Int) async -> [AIPick]?
    func plan(for wish: String) async -> AIQueryPlan?
    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]?
}

extension SearchAssistant {
    func recommend(_ wish: String, near center: GeoPoint, radius: Double, limit: Int) async -> [AIPick]? { nil }
}

// MARK: - Bevorzugter Anbieter, sonst der andere

/// Fragt zuerst den in den Einstellungen gewählten Anbieter, bei Fehlern den anderen.
final class FallbackAssistant: SearchAssistant {
    private let claude = ClaudeAssistant()
    private let apple = AppleIntelligenceAssistant()
    private(set) var lastProvider: AIProvider?

    private var order: [(AIProvider, any SearchAssistant)] {
        let preferred = AIProvider(rawValue: UserDefaults.standard.string(forKey: SettingsKey.aiProvider) ?? "") ?? .claude
        return preferred == .claude ? [(.claude, claude), (.apple, apple)] : [(.apple, apple), (.claude, claude)]
    }

    /// Empfehlungen gibt es nur von Claude – Apple Intelligence kennt zu wenige einzelne Orte.
    func recommend(_ wish: String, near center: GeoPoint, radius: Double, limit: Int) async -> [AIPick]? {
        guard order.first?.0 == .claude,
              let picks = await claude.recommend(wish, near: center, radius: radius, limit: limit) else { return nil }
        lastProvider = .claude
        return picks
    }

    func plan(for wish: String) async -> AIQueryPlan? {
        for (provider, assistant) in order {
            if let plan = await assistant.plan(for: wish) {
                lastProvider = provider
                return plan
            }
        }
        return nil
    }

    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]? {
        for (provider, assistant) in order {
            if let picks = await assistant.rank(wish, plan: plan, candidates: candidates, limit: limit), !picks.isEmpty {
                lastProvider = provider
                return picks
            }
        }
        return nil
    }
}

// MARK: - Claude über den Proxy

/// Claude (Anthropic) über die Endpunkte `/v1/spot-recommend` (Normalfall) sowie `/v1/spot-query` und
/// `/v1/spot-rank` (Ausweichweg) des Meanwhile-Proxys.
/// Der API-Key liegt nur auf dem Server; die App weist sich per App Attest aus.
final class ClaudeAssistant: SearchAssistant {
    private(set) var lastProvider: AIProvider?

    func recommend(_ wish: String, near center: GeoPoint, radius: Double, limit: Int) async -> [AIPick]? {
        guard AttestService.isSupported, let area = await Geocoder.area(for: center) else { return nil }
        let payload: [String: any Sendable] = ["text": wish, "area": area, "radiusKm": radius / 1_000, "limit": limit]
        guard let data = await ProxyService.shared.send("v1/spot-recommend", payload).data,
              let reply = try? JSONDecoder().decode(SpotRecommendReply.self, from: data) else { return nil }
        lastProvider = .claude
        return reply.picks
    }

    func plan(for wish: String) async -> AIQueryPlan? {
        guard AttestService.isSupported,
              let data = await ProxyService.shared.send("v1/spot-query", ["text": wish]).data,
              let reply = try? JSONDecoder().decode(SpotQueryReply.self, from: data) else { return nil }
        lastProvider = .claude
        return reply.plan
    }

    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]? {
        guard AttestService.isSupported, !candidates.isEmpty else { return nil }
        var places: [[String: String]] = []
        for (index, place) in candidates.enumerated() {
            let address: String = place.shortAddress ?? place.address ?? ""
            places.append(["id": "p\(index)", "name": place.name, "category": place.category ?? "", "address": address])
        }
        let payload: [String: any Sendable] = ["text": wish, "criteria": plan.criteria, "limit": limit, "places": places]
        guard let data = await ProxyService.shared.send("v1/spot-rank", payload).data,
              let reply = try? JSONDecoder().decode(SpotRankReply.self, from: data) else { return nil }
        lastProvider = .claude
        return reply.picks(candidateCount: candidates.count)
    }
}

nonisolated struct SpotRecommendReply: Decodable, Sendable {
    nonisolated struct Recommendation: Decodable, Sendable {
        let name: String
        let reason: String
    }

    let places: [Recommendation]

    /// Leere und doppelte Namen fallen heraus.
    var picks: [AIPick] {
        var seen = Set<String>()
        return places.compactMap { place in
            let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            let reason = place.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            return AIPick(suggestedName: name, reason: reason.isEmpty ? nil : reason)
        }
    }
}

nonisolated struct SpotQueryReply: Decodable, Sendable {
    let queries: [String]
    let criteria: String

    var plan: AIQueryPlan? {
        let terms = queries.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return terms.isEmpty ? nil : AIQueryPlan(queries: Array(terms.prefix(3)), criteria: criteria)
    }
}

nonisolated struct SpotRankReply: Decodable, Sendable {
    nonisolated struct Pick: Decodable, Sendable {
        let id: String
        let reason: String
    }

    let picks: [Pick]

    /// "p3" → Index 3. Unbekannte oder doppelte Ids fallen heraus.
    func picks(candidateCount: Int) -> [AIPick] {
        var seen = Set<Int>()
        return picks.compactMap { pick in
            guard pick.id.hasPrefix("p"), let index = Int(pick.id.dropFirst()),
                  index >= 0, index < candidateCount, seen.insert(index).inserted else { return nil }
            let reason = pick.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            return AIPick(index: index, reason: reason.isEmpty ? nil : reason)
        }
    }
}

// MARK: - Apple Intelligence auf dem Gerät

@Generable
nonisolated struct GeneratedQueryPlan {
    @Guide(description: "1 to 3 short search terms for Apple Maps: place types or categories, at most three words each, most important first", .count(1...3))
    var queries: [String]
    @Guide(description: "One short sentence with what matters beyond the place type, or an empty string")
    var criteria: String
}

@Generable
nonisolated struct GeneratedPick {
    @Guide(description: "The id of the place from the list, for example p3")
    var id: String
    @Guide(description: "One short sentence on why it fits, or an empty string if you do not know the place")
    var reason: String
}

@Generable
nonisolated struct GeneratedRanking {
    @Guide(description: "The places that fit the wish, best match first", .maximumCount(15))
    var picks: [GeneratedPick]
}

/// Apple Intelligence (Foundation Models) – kostenlos, privat, offline. Nur auf Geräten mit Apple Intelligence.
final class AppleIntelligenceAssistant: SearchAssistant {
    private(set) var lastProvider: AIProvider?

    nonisolated static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Apple Intelligence] \(message())")
        #endif
    }

    func plan(for wish: String) async -> AIQueryPlan? {
        guard Self.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You help people find places with Apple Maps. Turn the user's wish into short search terms that \
            Apple Maps understands: place types in \(AppLanguage.englishName), without the city and without \
            adjectives such as "quiet". Write the criteria in \(AppLanguage.englishName).
            """)
        let response: LanguageModelSession.Response<GeneratedQueryPlan>
        do {
            response = try await session.respond(to: "Wish: \(wish)", generating: GeneratedQueryPlan.self)
        } catch {
            Self.debugLog("Plan fehlgeschlagen: \(error)")
            return nil
        }
        let reply = SpotQueryReply(queries: response.content.queries, criteria: response.content.criteria)
        guard let plan = reply.plan else { return nil }
        lastProvider = .apple
        return plan
    }

    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]? {
        guard Self.isAvailable, !candidates.isEmpty else { return nil }
        let list = candidates.enumerated().map { index, place in
            "p\(index) | \(place.name) | \(place.category ?? "") | \(place.shortAddress ?? "")"
        }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You pick the best matches for a place search from a list of real places (id | name | category | address). \
            Return at most \(limit) places that fit the wish, best first, and leave out places that clearly do not fit. \
            Write each reason in \(AppLanguage.englishName). Never invent amenities, prices or opening hours; \
            use an empty reason if you do not know the place. Use only ids from the list.
            """)
        var prompt = "Wish: \(wish)"
        if !plan.criteria.isEmpty { prompt += "\nWhat matters: \(plan.criteria)" }
        prompt += "\nPlaces:\n\(list)"
        let response: LanguageModelSession.Response<GeneratedRanking>
        do {
            response = try await session.respond(to: prompt, generating: GeneratedRanking.self)
        } catch {
            Self.debugLog("Sortieren fehlgeschlagen: \(error)")
            return nil
        }
        let reply = SpotRankReply(picks: response.content.picks.map { .init(id: $0.id, reason: $0.reason) })
        let picks = Array(reply.picks(candidateCount: candidates.count).prefix(limit))
        guard !picks.isEmpty else { return nil }
        lastProvider = .apple
        return picks
    }
}

// MARK: - Beispieldaten

/// Für Tests und Screenshots: nimmt die Kandidaten in umgekehrter Reihenfolge und schreibt Begründungen dazu.
final class MockSearchAssistant: SearchAssistant {
    private(set) var lastProvider: AIProvider?
    private let delay: Duration

    init(delay: Duration = .milliseconds(500)) {
        self.delay = delay
    }

    func plan(for wish: String) async -> AIQueryPlan? {
        try? await Task.sleep(for: delay)
        lastProvider = .claude
        return AIQueryPlan(queries: [wish], criteria: "")
    }

    func rank(_ wish: String, plan: AIQueryPlan, candidates: [Place], limit: Int) async -> [AIPick]? {
        try? await Task.sleep(for: delay)
        lastProvider = .claude
        return candidates.indices.reversed().prefix(limit).map { index in
            AIPick(index: index, reason: String(localized: "Passt gut zu „\(wish)“ – ruhig und gemütlich."))
        }
    }
}
