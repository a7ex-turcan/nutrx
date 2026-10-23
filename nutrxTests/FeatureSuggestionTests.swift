import XCTest
@testable import nutrx

/// Settings → Suggest a feature (#142): the mailto draft.
final class FeatureSuggestionTests: XCTestCase {

    func testMailURL() throws {
        let url = FeatureSuggestion.mailURL(appVersion: "2.3.1", build: "152", systemVersion: "27.0", device: "iPhone")
        XCTAssertEqual(url.scheme, "mailto")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "support@nutrx-labs.com")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(items["subject"], "nutrx feature idea")
        // Room to write first, then the versions.
        XCTAssertEqual(items["body"], "\n\n\n—\nnutrx 2.3.1 (152) · iOS 27.0 · iPhone")
        // Spaces and line breaks are percent-encoded, so Mail doesn't cut the draft short.
        XCTAssertFalse(url.absoluteString.contains(" "))
        XCTAssertTrue(url.absoluteString.contains("%0A"))
    }

    func testMailURLForThisInstall() throws {
        let components = try XCTUnwrap(URLComponents(url: FeatureSuggestion.mailURL, resolvingAgainstBaseURL: false))
        let body = try XCTUnwrap(components.queryItems?.first { $0.name == "body" }?.value)
        let version = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertTrue(body.contains("nutrx \(version) ("))
        XCTAssertTrue(body.contains("· iOS \(UIDevice.current.systemVersion) ·"))
    }
}
