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
        XCTAssertEqual(WidgetSummary.inline(met: 0, total: 1, streakDays: 0, streaksEnabled: true), "0/1 goal")
        XCTAssertEqual(WidgetSummary.watchInline(met: 1, total: 1, streakDays: 2, streaksEnabled: true), "1/1 goal · 2 days")
        XCTAssertEqual(WidgetSummary.inline(met: 0, total: 0, streakDays: 10, streaksEnabled: true),
                       "Add a nutrient in nutrx")
    }

    func testWatchInline() {
        XCTAssertEqual(WidgetSummary.watchInline(met: 3, total: 6, streakDays: 10, streaksEnabled: true), "3/6 goals · 10 days")
        XCTAssertEqual(WidgetSummary.watchInline(met: 3, total: 6, streakDays: 1, streaksEnabled: true), "3/6 goals · 1 day")
        XCTAssertEqual(WidgetSummary.watchInline(met: 3, total: 6, streakDays: 0, streaksEnabled: true), "3/6 goals")
        XCTAssertEqual(WidgetSummary.watchInline(met: 3, total: 6, streakDays: 10, streaksEnabled: false), "3/6 goals")
        XCTAssertEqual(WidgetSummary.watchInline(met: 0, total: 0, streakDays: 0, streaksEnabled: true), "nutrx")
    }

    func testLogged() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(WidgetSummary.logged(1000, locale: locale), "+1,000 logged")
        XCTAssertEqual(WidgetSummary.logged(0.25, locale: locale), "+0.25 logged")
    }

    func testLoggedAnnouncement() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(WidgetSummary.loggedAnnouncement(1000, unit: "IU", name: "Vitamin D",
                                                        progress: "3,000 of 4,000 IU", locale: locale),
                       "Logged 1,000 IU of Vitamin D. 3,000 of 4,000 IU.")
        XCTAssertEqual(WidgetSummary.loggedAnnouncement(1, unit: "", name: "Water", progress: "6 of 8", locale: locale),
                       "Logged 1 of Water. 6 of 8.")
    }

    func testSegmentsOnePerGoalUpToTheCap() {
        XCTAssertTrue(WidgetSummary.segments(met: 3, total: 6) == (3, 6))
        XCTAssertTrue(WidgetSummary.segments(met: 0, total: 0) == (0, 0))
        XCTAssertTrue(WidgetSummary.segments(met: 9, total: 6) == (6, 6))  // clamped
    }

    func testSegmentsScaleBeyondTheCap() {
        XCTAssertTrue(WidgetSummary.segments(met: 12, total: 24) == (6, 12))
        XCTAssertTrue(WidgetSummary.segments(met: 23, total: 24) == (11, 12))  // only full when all met
        XCTAssertTrue(WidgetSummary.segments(met: 24, total: 24) == (12, 12))
    }

    func testNextLine() {
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: "Vitamin D", total: 6), "Next: Vitamin D")
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, total: 6), "All done for today")
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, total: 0), "Add a nutrient")
    }

    func testNextLineCountsGoalsOverALimitOnceNothingIsLeftToLog() {
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, overLimitCount: 1, total: 6), "1 over limit")
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: nil, overLimitCount: 2, total: 6), "2 over limit")
        // A goal to work toward still comes first.
        XCTAssertEqual(WidgetSummary.nextLine(firstUnmetName: "Iron", overLimitCount: 1, total: 6), "Next: Iron")
    }
}
