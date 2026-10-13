import Foundation

/// Failures surfaced by the App Store Connect client and its command-line front end.
public enum ASCError: Error, CustomStringConvertible {
    case missingEnvironment(String)
    case keyFileUnreadable(path: String, underlying: String)
    case invalidKey(String)
    case invalidURL(String)
    case foreignHost(String)
    case invalidJSON(String)
    case usage(String)

    public var description: String {
        switch self {
        case .missingEnvironment(let name):
            return "environment variable \(name) is not set"
        case .keyFileUnreadable(let path, let underlying):
            return "cannot read private key at \(path): \(underlying)"
        case .invalidKey(let reason):
            return "private key is not a valid P-256 PEM key: \(reason)"
        case .invalidURL(let text):
            return "not a valid request path: \(text)"
        case .foreignHost(let origin):
            return "refusing to send the API token to \(origin); pass a path such as /v1/apps or a URL on the API host"
        case .invalidJSON(let reason):
            return "request body is not valid JSON: \(reason)"
        case .usage(let text):
            return text
        }
    }
}
