import CryptoKit
import Foundation
import Testing

@testable import ASCKit

struct JWTSignerTests {
    private let issuedAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func tokenHasES256HeaderWithKeyIdentifier() throws {
        let key = P256.Signing.PrivateKey()
        let signer = try JWTSigner(
            keyIdentifier: "ABC123DEF4", issuerIdentifier: "issuer", privateKeyPEM: key.pemRepresentation)
        let segments = try signer.token(issuedAt: issuedAt).split(separator: ".")
        #expect(segments.count == 3)
        let header = try decodeJSON(segments[0])
        #expect(header["alg"] as? String == "ES256")
        #expect(header["kid"] as? String == "ABC123DEF4")
        #expect(header["typ"] as? String == "JWT")
    }

    @Test func claimsCarryIssuerAudienceAndClampedExpiry() throws {
        let key = P256.Signing.PrivateKey()
        let signer = try JWTSigner(
            keyIdentifier: "K", issuerIdentifier: "issuer-id", privateKeyPEM: key.pemRepresentation)
        let segments = try signer.token(issuedAt: issuedAt, lifetime: 3600).split(separator: ".")
        let claims = try decodeJSON(segments[1])
        #expect(claims["iss"] as? String == "issuer-id")
        #expect(claims["aud"] as? String == JWTSigner.audience)
        #expect(claims["iat"] as? Int == 1_700_000_000)
        #expect(claims["exp"] as? Int == 1_700_000_000 + Int(JWTSigner.maximumLifetime))
    }

    @Test func signatureVerifiesAgainstThePublicKey() throws {
        let key = P256.Signing.PrivateKey()
        let signer = try JWTSigner(keyIdentifier: "K", issuerIdentifier: "issuer", privateKeyPEM: key.pemRepresentation)
        let segments = try signer.token(issuedAt: issuedAt).split(separator: ".")
        let signingInput = Data((segments[0] + "." + segments[1]).utf8)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: decodeBase64URL(segments[2]))
        #expect(key.publicKey.isValidSignature(signature, for: signingInput))
    }

    @Test func rejectsKeysThatAreNotP256() {
        #expect(throws: ASCError.self) {
            try JWTSigner(keyIdentifier: "K", issuerIdentifier: "issuer", privateKeyPEM: "not a key")
        }
    }

    private func decodeJSON(_ segment: Substring) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: decodeBase64URL(segment))
        return try #require(object as? [String: Any])
    }

    private func decodeBase64URL(_ segment: Substring) throws -> Data {
        var text = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        text += String(repeating: "=", count: (4 - text.count % 4) % 4)
        return try #require(Data(base64Encoded: text))
    }
}
