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
    /// Without `ASC_KEY_PATH` (or with it empty) the key is read from
    /// `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, the location Apple's own tools use. The key material
    /// never leaves this process.
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
        let keyPath = keyPath(keyIdentifier: keyIdentifier, environment: environment)
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

    /// Where the private key is read from: `ASC_KEY_PATH` when it is set and not empty, like the two identifiers,
    /// otherwise `AuthKey_<KEY_ID>.p8` in `~/.appstoreconnect/private_keys/`.
    static func keyPath(
        keyIdentifier: String,
        environment: [String: String],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        if let path = environment["ASC_KEY_PATH"], !path.isEmpty { return path }
        return homeDirectory.appending(path: ".appstoreconnect/private_keys/AuthKey_\(keyIdentifier).p8")
            .path(percentEncoded: false)
    }

    /// The URL a request goes to. A path resolves against the API host; an absolute URL, such as a response's
    /// `links.next`, is accepted only on that same origin. Redirects are held to the same rule (`send`), so the
    /// bearer token never goes elsewhere.
    static func resolve(_ path: String, against baseURL: URL) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw ASCError.invalidURL(path) }
        guard isSameOrigin(url, as: baseURL) else {
            // The whole origin, so a wrong scheme or port reads as clearly as a wrong host.
            let origin = "\(url.scheme ?? "")://\(url.host ?? "")" + (url.port.map { ":\($0)" } ?? "")
            throw ASCError.foreignHost(origin)
        }
        return url
    }

    /// Whether `url` has `baseURL`'s scheme, host and port.
    static func isSameOrigin(_ url: URL, as baseURL: URL) -> Bool {
        url.scheme == baseURL.scheme && url.host == baseURL.host && url.port == baseURL.port
    }

    public func send(method: String, path: String, body: Data? = nil) async throws -> Response {
        let url = try Self.resolve(path, against: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try signer.token())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request, delegate: SameOriginRedirects(baseURL: baseURL))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return Response(status: status, body: data)
    }
}

/// Follows a redirect only within the API's own origin. URLSession would otherwise follow one anywhere, and the
/// request's headers, bearer token included, go with it. A refused redirect returns the 3xx response itself.
final class SameOriginRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let url = request.url, ASCClient.isSameOrigin(url, as: baseURL) else { return nil }
        return request
    }
}
