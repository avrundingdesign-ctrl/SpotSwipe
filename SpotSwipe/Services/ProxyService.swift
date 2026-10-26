import Foundation
import os

/// Transport zum Meanwhile-Proxy (`zwischenzeit-api.cleanyourstuff.nl`). Übernommen aus Meanwhile.
///
/// Der Google-Key liegt nur auf dem Server. Die App ruft feste Endpunkte auf und
/// weist sich per App Attest aus. Der Proxy akzeptiert SpotSwipe über
/// `APPLE_EXTRA_BUNDLE_IDS`.
///
/// Anfragen laufen strikt nacheinander: Der Proxy verlangt, dass der
/// Assertion-Zähler echt steigt, und würde überholende Anfragen ablehnen.
/// Ein `actor` allein genügt nicht – an jedem `await` darf ein weiterer Aufruf
/// hinein –, deshalb die explizite Warteschlange.
actor ProxyService {
    static let shared = ProxyService()

    private static let baseURL = URL(string: "https://zwischenzeit-api.cleanyourstuff.nl")!
    private static let log = Logger(subsystem: "com.avrundingdesign.spotswipe", category: "proxy")

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    // MARK: - Hinweise für die Oberfläche

    enum Notice {
        case unavailable, dailyLimit, budget

        var text: String {
            switch self {
            case .unavailable: String(localized: "Fotos und Bewertungen sind gerade nicht verfügbar.")
            case .dailyLimit: String(localized: "Tageslimit für Fotos erreicht – morgen geht es weiter.")
            case .budget: String(localized: "Fotos pausieren gerade. Bitte später erneut versuchen.")
            }
        }
    }

    private var pendingNotice: Notice?

    func consumeNotice() -> String? {
        defer { pendingNotice = nil }
        return pendingNotice?.text
    }

    // MARK: - Warteschlange

    private var tail: Task<Void, Never> = Task {}

    private func serialized<T: Sendable>(_ work: @Sendable @escaping () async -> T) async -> T {
        let previous = tail
        let task = Task { () -> T in
            _ = await previous.value
            return await work()
        }
        tail = Task { _ = await task.value }
        return await task.value
    }

    // MARK: - Registrierung

    func fetchChallenge() async -> String? {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v1/challenge"))
        request.httpMethod = "POST"
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return reply["challenge"]
    }

    func register(keyID: String, attestation: String, challenge: String) async -> Bool {
        let payload = ["keyId": keyID, "attestation": attestation, "challenge": challenge]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v1/attest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        guard let (_, response) = try? await session.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Fachliche Aufrufe

    /// Sendet `payload` an `path` und liefert den Antwortkörper, bei jedem Fehler `nil`.
    func send(_ path: String, _ payload: [String: any Sendable]) async -> Data? {
        var payload = payload
        // Google liefert Öffnungszeiten in dieser Sprache ("Montag: 08:00–18:00").
        payload["lang"] = AppLanguage.code
        payload["units"] = Locale.current.measurementSystem == .metric ? "metric" : "imperial"

        // Genau einmal serialisieren: Die Signatur gilt für diese Bytes.
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }
        return await serialized { [self] in
            await perform(path: path, body: body, allowRetry: true)
        }
    }

    private func perform(path: String, body: Data, allowRetry: Bool) async -> Data? {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let signed = try await AttestService.shared.assertion(for: body)
            request.setValue(signed.keyID, forHTTPHeaderField: "X-Attest-Key-Id")
            request.setValue(signed.assertion, forHTTPHeaderField: "X-Attest-Assertion")
        } catch {
            Self.log.error("App Attest fehlgeschlagen bei \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            pendingNotice = .unavailable
            return nil
        }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else {
            Self.log.error("Netzwerkfehler bei \(path, privacy: .public)")
            pendingNotice = .unavailable
            return nil
        }

        switch http.statusCode {
        case 200:
            return data
        case 401:
            // Der Proxy kennt das Gerät nicht mehr: einmal neu registrieren und wiederholen.
            await AttestService.shared.forget()
            guard allowRetry else {
                pendingNotice = .unavailable
                return nil
            }
            return await perform(path: path, body: body, allowRetry: false)
        case 429:
            pendingNotice = .dailyLimit
        case 503:
            pendingNotice = .budget
        default:
            Self.log.error("Proxy antwortete \(http.statusCode) bei \(path, privacy: .public)")
            pendingNotice = .unavailable
        }
        return nil
    }
}
