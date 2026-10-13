import Foundation

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
