import SwiftData
import XCTest
@testable import nutrx

/// Rating from Settings counts as this version's review prompt, so the automatic one doesn't follow it.
final class ReviewServiceTests: XCTestCase {

    func testRecordingAPromptMarksThisVersionAndStartsTheCooldown() throws {
        let container = try ModelContainer.inMemoryForTests()  // keep alive for the context's lifetime
        let context = container.mainContext
        let preferences = UserPreferences()
        context.insert(preferences)

        ReviewService.recordPrompt(context: context)

        XCTAssertEqual(preferences.lastReviewRequestedVersion, Bundle.main.appVersion)
        let recorded = try XCTUnwrap(preferences.lastReviewRequestedDate)
        XCTAssertLessThan(abs(recorded.timeIntervalSinceNow), 5)
    }

    func testWriteReviewURLOpensNutrxsReviewPage() throws {
        let components = try XCTUnwrap(URLComponents(url: ReviewService.writeReviewURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "apps.apple.com")
        XCTAssertEqual(components.path, "/app/id\(ReviewService.appStoreID)")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "action", value: "write-review")])
    }

    func testAppStoreIDIsNutrxsAppRecord() {
        // App Store Connect: "nutrx - Nutrient Tracker", bundle nutrx-labs.nutrx.
        XCTAssertEqual(ReviewService.appStoreID, "6760843478")
    }
}
