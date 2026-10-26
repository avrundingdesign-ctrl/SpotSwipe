import Foundation
import os

/// Ergebnis eines Proxy-Aufrufs. Die Aufrufer entscheiden selbst, welchen Hinweis sie zeigen.
nonisolated enum ProxyResult: Sendable {
    case ok(Data)
    case unavailable
    case dailyLimit
    case budget

    var data: Data? {
        if case .ok(let data) = self { return data }
        return nil
    }
}

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

    /// Sendet `payload` an `path`.
    func send(_ path: String, _ payload: [String: any Sendable]) async -> ProxyResult {
        var payload = payload
        // Google liefert Öffnungszeiten in dieser Sprache ("Montag: 08:00–18:00").
        payload["lang"] = AppLanguage.code
        payload["units"] = Locale.current.measurementSystem == .metric ? "metric" : "imperial"

        // Genau einmal serialisieren: Die Signatur gilt für diese Bytes.
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return .unavailable
        }
        return await serialized { [self] in
            await perform(path: path, body: body, allowRetry: true)
        }
    }

    private func perform(path: String, body: Data, allowRetry: Bool) async -> ProxyResult {
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
            return .unavailable
        }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else {
            Self.log.error("Netzwerkfehler bei \(path, privacy: .public)")
            return .unavailable
        }

        switch http.statusCode {
        case 200:
            return .ok(data)
        case 401:
            // Der Proxy kennt das Gerät nicht mehr: einmal neu registrieren und wiederholen.
            await AttestService.shared.forget()
            guard allowRetry else { return .unavailable }
            return await perform(path: path, body: body, allowRetry: false)
        case 429:
            return .dailyLimit
        case 503:
            return .budget
        default:
            Self.log.error("Proxy antwortete \(http.statusCode) bei \(path, privacy: .public)")
            return .unavailable
        }
    }
}
