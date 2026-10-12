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
}
