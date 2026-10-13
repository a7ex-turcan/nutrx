import Foundation
import Testing

@testable import ASCKit

struct ASCClientTests {
    private let apiHost = "https://api.appstoreconnect.apple.com"

    @Test func pathsResolveAgainstTheAPIHost() throws {
        let baseURL = try #require(URL(string: apiHost))
        let url = try ASCClient.resolve("/v1/apps/123?limit=5", against: baseURL)
        #expect(url.absoluteString == "https://api.appstoreconnect.apple.com/v1/apps/123?limit=5")
    }

    @Test func absoluteURLsOnTheAPIHostAreAccepted() throws {
        // A response's `links.next` is an absolute URL on the same host.
        let baseURL = try #require(URL(string: apiHost))
        let next = "https://api.appstoreconnect.apple.com/v1/apps?cursor=AB&limit=5"
        #expect(try ASCClient.resolve(next, against: baseURL).absoluteString == next)
    }

    @Test(arguments: [
        "https://example.com/v1/apps",
        "//example.com/v1/apps",
        "http://api.appstoreconnect.apple.com/v1/apps",
        "https://api.appstoreconnect.apple.com:8443/v1/apps",
    ])
    func otherHostsSchemesAndPortsAreRefused(path: String) throws {
        let baseURL = try #require(URL(string: apiHost))
        let error = #expect(throws: ASCError.self) { try ASCClient.resolve(path, against: baseURL) }
        guard case .foreignHost? = error else {
            Issue.record("expected .foreignHost, got \(String(describing: error))")
            return
        }
    }

    @Test func theRefusalNamesTheWholeOrigin() throws {
        let baseURL = try #require(URL(string: apiHost))
        let error = #expect(throws: ASCError.self) {
            try ASCClient.resolve("http://api.appstoreconnect.apple.com:8080/v1/apps", against: baseURL)
        }
        guard case .foreignHost(let origin)? = error else {
            Issue.record("expected .foreignHost, got \(String(describing: error))")
            return
        }
        #expect(origin == "http://api.appstoreconnect.apple.com:8080")
    }

    @Test(arguments: [
        ("https://api.appstoreconnect.apple.com/v1/apps?cursor=AB", true),
        ("https://example.com/v1/apps", false),
        ("http://api.appstoreconnect.apple.com/v1/apps", false),
        ("https://api.appstoreconnect.apple.com:8443/v1/apps", false),
    ])
    func redirectsAreFollowedOnlyWithinTheAPIOrigin(target: String, followed: Bool) async throws {
        let baseURL = try #require(URL(string: apiHost))
        let from = try #require(URL(string: "https://api.appstoreconnect.apple.com/v1/apps"))
        let to = try #require(URL(string: target))
        let response = try #require(
            HTTPURLResponse(url: from, statusCode: 302, httpVersion: nil, headerFields: ["Location": target]))
        let task = URLSession.shared.dataTask(with: from)  // never resumed; the delegate only needs a task
        let next = await SameOriginRedirects(baseURL: baseURL).urlSession(
            .shared, task: task, willPerformHTTPRedirection: response, newRequest: URLRequest(url: to))
        #expect((next != nil) == followed)
    }

    @Test func theKeyDefaultsToApplesLocation() {
        let path = ASCClient.keyPath(
            keyIdentifier: "ABC123", environment: [:], homeDirectory: URL(filePath: "/Users/someone"))
        #expect(path == "/Users/someone/.appstoreconnect/private_keys/AuthKey_ABC123.p8")
    }

    @Test func anEmptyKeyPathFallsBackToTheDefault() {
        let path = ASCClient.keyPath(
            keyIdentifier: "ABC123", environment: ["ASC_KEY_PATH": ""], homeDirectory: URL(filePath: "/Users/someone"))
        #expect(path == "/Users/someone/.appstoreconnect/private_keys/AuthKey_ABC123.p8")
    }

    @Test func aKeyPathOverridesTheDefault() {
        let path = ASCClient.keyPath(
            keyIdentifier: "ABC123", environment: ["ASC_KEY_PATH": "/tmp/key.p8"],
            homeDirectory: URL(filePath: "/Users/someone"))
        #expect(path == "/tmp/key.p8")
    }
}
