import XCTest
@testable import nutrx

/// DESIGN.md §5.10 — the widgets' text.
final class WidgetSummaryTests: XCTestCase {

    func testScore() {
        XCTAssertEqual(WidgetSummary.score(met: 3, total: 6), "3/6")
    }

    func testStreakOnlyWhenOnAndRunning() {
        XCTAssertEqual(WidgetSummary.streak(days: 10, enabled: true), "10-day streak")
        XCTAssertEqual(WidgetSummary.streak(days: 1, enabled: true), "1-day streak")
        XCTAssertNil(WidgetSummary.streak(days: 0, enabled: true))
        XCTAssertNil(WidgetSummary.streak(days: 10, enabled: false))
    }

    func testInline() {
        XCTAssertEqual(WidgetSummary.inline(met: 3, total: 6, streakDays: 10, streaksEnabled: true),
                       "3/6 goals · 10-day streak")
        XCTAssertEqual(WidgetSummary.inline(met: 3, total: 6, streakDays: 0, streaksEnabled: true), "3/6 goals")
        XCTAssertEqual(WidgetSummary.inline(met: 3, total: 6, streakDays: 10, streaksEnabled: false), "3/6 goals")
        XCTAssertEqual(WidgetSummary.inline(met: 0, total: 0, streakDays: 10, streaksEnabled: true),
                       "Add a nutrient in nutrx")
    }

    func testNextLine() {
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: "Vitamin D", total: 6), "Next: Vitamin D")
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, total: 6), "All done for today")
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, total: 0), "Add a nutrient")
    }
}
