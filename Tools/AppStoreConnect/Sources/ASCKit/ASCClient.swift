import Foundation

/// A thin authenticated HTTP client for the App Store Connect API.
///
/// It knows nothing about individual endpoints; callers pass the documented path (for example
/// `/v1/bundleIds?limit=5`) and an optional JSON body, and get the status code and raw response back.
public struct ASCClient {
    public struct Response {
        public let status: Int
        public let body: Data

        public var isSuccess: Bool { (200..<300).contains(status) }
    }

    public let baseURL: URL
    private let signer: JWTSigner
    private let session: URLSession

    public init(signer: JWTSigner, session: URLSession = .shared) throws {
        let base = "https://api.appstoreconnect.apple.com"
        guard let url = URL(string: base) else { throw ASCError.invalidURL(base) }
        self.baseURL = url
        self.signer = signer
        self.session = session
    }

    /// Builds a client from `ASC_KEY_ID`, `ASC_ISSUER_ID` and, optionally, `ASC_KEY_PATH`.
    ///
    /// Without `ASC_KEY_PATH` the key is read from `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`,
    /// the location Apple's own tools use. The key material never leaves this process.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    )
        throws -> ASCClient
    {
        guard let keyIdentifier = environment["ASC_KEY_ID"], !keyIdentifier.isEmpty else {
            throw ASCError.missingEnvironment("ASC_KEY_ID")
        }
        guard let issuerIdentifier = environment["ASC_ISSUER_ID"], !issuerIdentifier.isEmpty else {
            throw ASCError.missingEnvironment("ASC_ISSUER_ID")
        }
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".appstoreconnect/private_keys/AuthKey_\(keyIdentifier).p8")
            .path(percentEncoded: false)
        let keyPath = environment["ASC_KEY_PATH"] ?? defaultPath
        let pem: String
        do {
            pem = try String(contentsOfFile: keyPath, encoding: .utf8)
        } catch {
            throw ASCError.keyFileUnreadable(path: keyPath, underlying: String(describing: error))
        }
        let signer = try JWTSigner(
            keyIdentifier: keyIdentifier, issuerIdentifier: issuerIdentifier, privateKeyPEM: pem)
        return try ASCClient(signer: signer)
    }

    public func send(method: String, path: String, body: Data? = nil) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw ASCError.invalidURL(path) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try signer.token())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return Response(status: status, body: data)
    }
}
