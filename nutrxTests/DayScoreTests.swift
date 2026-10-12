import XCTest
@testable import nutrx

/// DESIGN.md §4.3 — the day-score card headline.
final class DayScoreTests: XCTestCase {

    func testNothingMetIsLetsGetStarted() {
        XCTAssertEqual(DayScore(met: 0, total: 6).title, "Let's get started")
    }

    func testEverythingMetIsAllDone() {
        XCTAssertEqual(DayScore(met: 6, total: 6).title, "All done for today")
    }

    func testHalfMetIsHalfwayThere() {
        XCTAssertEqual(DayScore(met: 3, total: 6).title, "Halfway there — 3\u{00A0}to\u{00A0}go")
    }

    func testFortyAndSixtyPercentAreStillHalfway() {
        XCTAssertEqual(DayScore(met: 2, total: 5).title, "Halfway there — 3\u{00A0}to\u{00A0}go")  // 40%
        XCTAssertEqual(DayScore(met: 3, total: 5).title, "Halfway there — 2\u{00A0}to\u{00A0}go")  // 60%
    }

    func testOutsideFortyToSixtyPercentIsJustCountToGo() {
        XCTAssertEqual(DayScore(met: 1, total: 6).title, "5\u{00A0}to\u{00A0}go")  // 17%
        XCTAssertEqual(DayScore(met: 5, total: 6).title, "1\u{00A0}to\u{00A0}go")  // 83%
        XCTAssertEqual(DayScore(met: 1, total: 3).title, "2\u{00A0}to\u{00A0}go")  // 33%
    }

    func testNoNutrientsIsLetsGetStarted() {
        let score = DayScore(met: 0, total: 0)
        XCTAssertEqual(score.title, "Let's get started")
        XCTAssertEqual(score.remaining, 0)
    }

    func testMetIsClampedToTotal() {
        let score = DayScore(met: 9, total: 4)
        XCTAssertEqual(score.met, 4)
        XCTAssertEqual(score.title, "All done for today")
    }

    func testCountsGoalsThatCountAsMet() {
        let score = DayScore(progresses: [
            GoalProgress(current: 4000, goalType: .minimum, target: 4000),   // met
            GoalProgress(current: 100, goalType: .minimum, target: 4000),    // in progress
            GoalProgress(current: 350, goalType: .maximum, target: 400),     // nearing limit, still met
            GoalProgress(current: 450, goalType: .maximum, target: 400),     // over
            GoalProgress(current: 130, goalType: .range, target: 120, upperBound: 160),  // in range
        ])
        XCTAssertEqual(score, DayScore(met: 3, total: 5))
    }
}
