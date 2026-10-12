import XCTest
@testable import nutrx

/// DESIGN.md §4.8 — the analytics period stats and the stat-triplet text.
final class AnalyticsSummaryTests: XCTestCase {
    private let atLeast4000 = AnalyticsGoal(goalType: .minimum, target: 4000, upperBound: nil)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// Monday 12 October 2026, midday.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
    }

    /// Day totals keyed by start of day, given as (days ago, total).
    private func totals(_ entries: [(Int, Double)]) -> [Date: Double] {
        Dictionary(uniqueKeysWithValues: entries.map { (day($0.0), $0.1) })
    }

    private func summary(_ dayCount: Int = 7, totals: [Date: Double] = [:], goal: AnalyticsGoal? = nil,
                         createdDaysAgo: Int = 120) -> AnalyticsSummary {
        AnalyticsSummary(dayCount: dayCount, totals: totals, goal: goal ?? atLeast4000,
                         createdAt: day(createdDaysAgo), today: now, calendar: calendar)
    }

    // MARK: - Days

    func testDaysCoverThePeriodEndingTodayOldestFirst() {
        let days = summary(30).days
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first?.date, day(29))
        XCTAssertEqual(days.last?.date, day(0))
        XCTAssertEqual(days.filter(\.isToday).map(\.date), [day(0)])
    }

    func testMissingDaysAreZeroAndNegativeTotalsFloorAtZero() {
        let days = summary(totals: totals([(2, -500)])).days
        XCTAssertEqual(days.map(\.total), Array(repeating: 0, count: 7))
    }

    // MARK: - Counted days

    func testTodayIsDrawnButNotCounted() {
        let summary = summary(totals: totals([(0, 5000)]))
        XCTAssertEqual(summary.days.last?.total, 5000)
        XCTAssertEqual(summary.days.last?.countsAsMet, true)
        XCTAssertEqual(summary.countedDays, 6)
        XCTAssertEqual(summary.metDays, 0)
        XCTAssertNil(summary.bestDay)
    }

    func testDaysBeforeTheNutrientExistedAreNotCounted() {
        let summary = summary(totals: totals([(5, 4000), (2, 4000)]), createdDaysAgo: 3)
        XCTAssertEqual(summary.days.filter(\.isTracked).map(\.date), [day(3), day(2), day(1), day(0)])
        XCTAssertEqual(summary.countedDays, 3)
        XCTAssertEqual(summary.metDays, 1)
        XCTAssertEqual(summary.hitRate!, 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(summary.average!, 4000.0 / 3, accuracy: 1e-9)
    }

    func testCreatedTodayHasNoStats() {
        let summary = summary(totals: totals([(0, 4000)]), createdDaysAgo: 0)
        XCTAssertEqual(summary.countedDays, 0)
        XCTAssertNil(summary.hitRate)
        XCTAssertNil(summary.average)
        XCTAssertNil(summary.bestDay)
    }

    // MARK: - Stats

    func testHitRateAverageAndBestDay() {
        // The mockup's week: 5 of 6 days met, Friday the best.
        let summary = summary(totals: totals([(6, 4000), (5, 4000), (4, 1500), (3, 5000), (2, 4000), (1, 4000)]))
        XCTAssertEqual(summary.metDays, 5)
        XCTAssertEqual(summary.countedDays, 6)
        XCTAssertEqual(summary.hitRate!, 5.0 / 6, accuracy: 1e-9)
        XCTAssertEqual(summary.average!, 22_500.0 / 6, accuracy: 1e-9)
        XCTAssertEqual(summary.bestDay?.date, day(3))
        XCTAssertEqual(summary.bestDay?.total, 5000)
    }

    func testBestDayTieGoesToTheEarliestDay() {
        let summary = summary(totals: totals([(4, 5000), (2, 5000), (1, 3000)]))
        XCTAssertEqual(summary.bestDay?.date, day(4))
    }

    func testAtMostGoalCountsQuietDaysAsMet() {
        let atMost400 = AnalyticsGoal(goalType: .maximum, target: 400, upperBound: nil)
        let summary = summary(totals: totals([(2, 500), (1, 300)]), goal: atMost400)
        XCTAssertEqual(summary.metDays, 5)  // everything but the 500 day
        XCTAssertEqual(summary.countedDays, 6)
    }

    func testRangeGoalNeedsBothBounds() {
        let range = AnalyticsGoal(goalType: .range, target: 100, upperBound: 200)
        let summary = summary(totals: totals([(3, 50), (2, 150), (1, 250)]), goal: range)
        XCTAssertEqual(summary.days.filter(\.countsAsMet).map(\.date), [day(2)])
    }

    // MARK: - Stat triplet text

    private let enUS = Locale(identifier: "en_US")

    func testTripletForTheMockupWeek() {
        let summary = summary(totals: totals([(6, 4000), (5, 4000), (4, 1500), (3, 5000), (2, 4000), (1, 4000)]))
        let stats = AnalyticsStat.triplet(for: summary, period: .week, unit: "IU", goalType: .minimum,
                                          calendar: calendar, locale: enUS)
        XCTAssertEqual(stats, [
            AnalyticsStat(label: "Hit rate", value: "83", suffix: "%", caption: "5 of 6 days"),
            AnalyticsStat(label: "Daily avg", value: "3,750", caption: "IU"),
            AnalyticsStat(label: "Best day", value: "5,000", caption: "Friday"),
        ])
    }

    func testBestDayCaptionIsADateOverLongerPeriods() {
        let summary = summary(30, totals: totals([(3, 5000)]))
        let stats = AnalyticsStat.triplet(for: summary, period: .month, unit: "IU", goalType: .minimum,
                                          calendar: calendar, locale: enUS)
        XCTAssertEqual(stats[2].caption, "Oct 9")
    }

    func testLimitsAndRangesCallItPeakDay() {
        let summary = summary(totals: totals([(1, 300)]))
        for goalType in [GoalType.maximum, .range] {
            let stats = AnalyticsStat.triplet(for: summary, period: .week, unit: "mg", goalType: goalType,
                                              calendar: calendar, locale: enUS)
            XCTAssertEqual(stats[2].label, "Peak day")
        }
    }

    func testTripletWithNothingToCountShowsDashes() {
        let summary = summary(createdDaysAgo: 0)
        let stats = AnalyticsStat.triplet(for: summary, period: .week, unit: "IU", goalType: .minimum,
                                          calendar: calendar, locale: enUS)
        XCTAssertEqual(stats.map(\.value), ["—", "—", "—"])
        XCTAssertNil(stats[0].suffix)
        XCTAssertEqual(stats[0].caption, "No full days yet")
        XCTAssertEqual(stats[2].caption, "Nothing logged")
    }

    func testSingleCountedDayIsSingular() {
        let summary = summary(totals: totals([(1, 4000)]), createdDaysAgo: 1)
        let stats = AnalyticsStat.triplet(for: summary, period: .week, unit: "IU", goalType: .minimum,
                                          calendar: calendar, locale: enUS)
        XCTAssertEqual(stats[0].caption, "1 of 1 day")
        XCTAssertEqual(stats[0].value, "100")
    }

    func testAverageUsesFewerDecimalsAsItGrows() {
        XCTAssertEqual(AnalyticsStat.averageText(3828.57, locale: enUS), "3,829")
        XCTAssertEqual(AnalyticsStat.averageText(12.44, locale: enUS), "12.4")
        XCTAssertEqual(AnalyticsStat.averageText(1.234, locale: enUS), "1.23")
        XCTAssertEqual(AnalyticsStat.averageText(8, locale: enUS), "8")
    }
}
