import XCTest
@testable import nutrx

/// Supply copy: Today's hint, the analytics card and the Supply sheet's sentence.
final class SupplyTextTests: XCTestCase {
    private let enUS = Locale(identifier: "en_US")
    private let refilled = Date(timeIntervalSince1970: 1_786_881_600)  // 2026-08-16 12:00 UTC

    private func status(level: SupplySchedule.Level, remaining: Double = 12_000, dailyUse: Double? = 2000,
                        daysLeft: Int? = 6) -> SupplySchedule.Status {
        .init(setup: .init(servings: 120, servingAmount: 1000, refilledAt: refilled, reminderDays: 7),
              remaining: remaining, dailyUse: dailyUse, daysLeft: daysLeft, level: level)
    }

    func testTodayHintOnlyWhenLowOrOut() {
        XCTAssertEqual(SupplyText.todayHint(status(level: .low)), "About 6 days left")
        XCTAssertEqual(SupplyText.todayHint(status(level: .low, daysLeft: 1)), "About 1 day left")
        XCTAssertEqual(SupplyText.todayHint(status(level: .low, daysLeft: 0)), "Runs out today")
        XCTAssertEqual(SupplyText.todayHint(status(level: .out, remaining: 0, daysLeft: 0)), "Out of supply")
        XCTAssertNil(SupplyText.todayHint(status(level: .plenty, daysLeft: 50)))
        XCTAssertNil(SupplyText.todayHint(status(level: .noHistory, dailyUse: nil, daysLeft: nil)))
    }

    func testCardCountAndExplanation() {
        XCTAssertEqual(SupplyText.servingsLine(status(level: .low), locale: enUS), "**12** of 120 left")
        let now = Date(timeIntervalSince1970: 1_791_979_200)  // 2026-10-14
        let explanation = SupplyText.explanation(status(level: .low), unit: "IU", now: now, locale: enUS)
        XCTAssertEqual(explanation, "At your usual **2,000 IU** a day. Reminder at 7 days left. Last refilled August 16.")
        let nextYear = Date(timeIntervalSince1970: 1_823_515_200)  // 2027-10-14
        XCTAssertTrue(SupplyText.explanation(status(level: .low), unit: "IU", now: nextYear, locale: enUS)
            .hasSuffix("Last refilled August 16, 2026."))
        XCTAssertEqual(SupplyText.explanation(status(level: .noHistory, dailyUse: nil, daysLeft: nil), unit: "IU", locale: enUS),
                       "Days-left estimate after a few days of logging.")
    }

    func testBottleSentenceUsesUsualUseThenTheGoal() {
        XCTAssertEqual(SupplyText.bottleSentence(servings: 120, servingAmount: 1000, unit: "IU", dailyUse: 2000,
                                                 dailyGoal: 4000, locale: enUS),
                       "That's **120,000 IU** — about 60 days at your usual 2,000 IU a day.")
        XCTAssertEqual(SupplyText.bottleSentence(servings: 120, servingAmount: 1000, unit: "IU", dailyUse: nil,
                                                 dailyGoal: 4000, locale: enUS),
                       "That's **120,000 IU** — about 30 days at your goal of 4,000 IU a day.")
        XCTAssertEqual(SupplyText.bottleSentence(servings: 30, servingAmount: 1, unit: "", dailyUse: nil, dailyGoal: 0,
                                                 locale: enUS),
                       "That's **30**.")
    }

    func testAveragesShowAsRoundNumbers() {
        XCTAssertEqual(SupplyText.usual(3928.57), 3930)
        XCTAssertEqual(SupplyText.usual(412.5), 413)
        XCTAssertEqual(SupplyText.usual(1.86), 1.9)
        XCTAssertEqual(SupplyText.bottleSentence(servings: 120, servingAmount: 1000, unit: "IU", dailyUse: 3928.57,
                                                 dailyGoal: 4000, locale: enUS),
                       "That's **120,000 IU** — about 30 days at your usual 3,930 IU a day.")
    }

    func testShortHint() {
        XCTAssertEqual(SupplyText.shortHint(status(level: .low)), "6 days left")
        XCTAssertEqual(SupplyText.shortHint(status(level: .out, remaining: 0, daysLeft: 0)), "Out of supply")
        XCTAssertEqual(SupplyText.compactHint(status(level: .low)), "6 days")
        XCTAssertEqual(SupplyText.compactHint(status(level: .low, daysLeft: 0)), "Today")
        XCTAssertNil(SupplyText.compactHint(status(level: .plenty, daysLeft: 50)))
    }

    func testFormSummary() {
        XCTAssertEqual(SupplyText.formSummary(servings: nil), "Off")
        XCTAssertEqual(SupplyText.formSummary(servings: 1), "1 serving")
        XCTAssertEqual(SupplyText.formSummary(servings: 120, locale: enUS), "120 servings")
    }

    func testTheTeaserFitsAnyNutrient() {
        // Shown on Water and Caffeine too, which don't come in a bottle (#85).
        XCTAssertEqual(SupplyText.teaser, "Know when you're running low.")
        XCTAssertFalse(SupplyText.teaser.localizedCaseInsensitiveContains("bottle"))
    }
}
