import CryptoKit
import DeviceCheck
import Foundation

/// Apple App Attest: beweist dem Proxy, dass eine Anfrage aus dieser echten,
/// unmanipulierten App auf einem echten Gerät kommt. Übernommen aus Meanwhile.
///
/// Der Schlüssel entsteht in der Secure Enclave und verlässt sie nie. Damit
/// braucht die App keinen API-Key, der sich aus dem Bundle auslesen ließe.
///
/// Im Simulator gibt es kein App Attest; dort bleiben Fotos und Bewertungen leer.
actor AttestService {
    static let shared = AttestService()

    private let service = DCAppAttestService.shared
    private let defaultsKey = "spotswipe.attest.keyID"

    /// Registrierte Schlüssel-ID. `nil`, solange sich das Gerät noch nicht beim Proxy angemeldet hat.
    private var cachedKeyID: String?

    private init() {
        cachedKeyID = UserDefaults.standard.string(forKey: defaultsKey)
    }

    nonisolated static var isSupported: Bool { DCAppAttestService.shared.isSupported }

    enum AttestError: Error {
        case unsupported
        case challengeFailed
        case registrationFailed
    }

    /// Liefert die Schlüssel-ID und registriert das Gerät beim ersten Aufruf.
    func ensureRegistered() async throws -> String {
        if let cachedKeyID { return cachedKeyID }
        guard service.isSupported else { throw AttestError.unsupported }

        // 1. Schlüssel in der Secure Enclave erzeugen.
        let keyID = try await service.generateKey()

        // 2. Einmal-Challenge vom Proxy holen.
        guard let challenge = await ProxyService.shared.fetchChallenge(),
              let challengeData = Data(base64Encoded: challenge) else {
            throw AttestError.challengeFailed
        }

        // 3. Attestierung über den Hash der Challenge erzeugen.
        let hash = Data(SHA256.hash(data: challengeData))
        let attestation = try await service.attestKey(keyID, clientDataHash: hash)

        // 4. Beim Proxy registrieren.
        let ok = await ProxyService.shared.register(
            keyID: keyID,
            attestation: attestation.base64EncodedString(),
            challenge: challenge
        )
        guard ok else { throw AttestError.registrationFailed }

        UserDefaults.standard.set(keyID, forKey: defaultsKey)
        cachedKeyID = keyID
        return keyID
    }

    /// Signiert genau diesen Anfragekörper; die Signatur passt auf keine andere Anfrage.
    func assertion(for body: Data) async throws -> (keyID: String, assertion: String) {
        let keyID = try await ensureRegistered()
        let hash = Data(SHA256.hash(data: body))
        let assertion = try await service.generateAssertion(keyID, clientDataHash: hash)
        return (keyID, assertion.base64EncodedString())
    }

    /// Verwirft die Registrierung, wenn der Proxy das Gerät nicht mehr kennt.
    func forget() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        cachedKeyID = nil
    }
}
