import CryptoKit
import Foundation

/// Mints the short-lived ES256 bearer tokens the App Store Connect API expects.
///
/// Apple documents the token shape under "Generating Tokens for API Requests": an ES256 JWT whose
/// header carries the key identifier and whose claims carry the issuer, issue and expiry times (at most
/// twenty minutes apart) and the fixed audience `appstoreconnect-v1`.
public struct JWTSigner {
    public static let audience = "appstoreconnect-v1"
    public static let maximumLifetime: TimeInterval = 20 * 60

    public let keyIdentifier: String
    public let issuerIdentifier: String
    private let privateKey: P256.Signing.PrivateKey

    public init(keyIdentifier: String, issuerIdentifier: String, privateKeyPEM: String) throws {
        self.keyIdentifier = keyIdentifier
        self.issuerIdentifier = issuerIdentifier
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            throw ASCError.invalidKey(String(describing: error))
        }
    }

    /// A token valid from `issuedAt` for `lifetime` seconds (clamped to Apple's twenty-minute maximum).
    public func token(issuedAt: Date = .now, lifetime: TimeInterval = 15 * 60) throws -> String {
        let lifetime = min(max(lifetime, 1), Self.maximumLifetime)
        let header: [String: Any] = ["alg": "ES256", "kid": keyIdentifier, "typ": "JWT"]
        let claims: [String: Any] = [
            "iss": issuerIdentifier,
            "iat": Int(issuedAt.timeIntervalSince1970),
            "exp": Int(issuedAt.addingTimeInterval(lifetime).timeIntervalSince1970),
            "aud": Self.audience,
        ]
        let signingInput = try Self.encodeSegment(header) + "." + Self.encodeSegment(claims)
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return signingInput + "." + Self.base64URL(signature.rawRepresentation)
    }

    static func encodeSegment(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return base64URL(data)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
