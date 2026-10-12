import XCTest
@testable import nutrx

/// DESIGN.md §4.8 — the weekday heatmap and its insight line.
final class WeekdayPatternTests: XCTestCase {
    private let atLeastOne = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)

    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// Monday 12 October 2026, midday.
    private let now = Date(timeIntervalSince1970: 1_791_806_400)

    private func day(_ offset: Int, _ calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
    }

    /// Met (total 1) on every day of the last `days` days except those `missed` returns true for.
    private func totals(days: Int = 40, calendar: Calendar, missed: (Date) -> Bool = { _ in false }) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for offset in 0..<days {
            let date = day(offset, calendar)
            totals[date] = missed(date) ? 0 : 1
        }
        return totals
    }

    private func pattern(_ totals: [Date: Double], createdDaysAgo: Int = 120,
                         calendar: Calendar) -> WeekdayPattern {
        WeekdayPattern(totals: totals, goal: atLeastOne, createdAt: day(createdDaysAgo, calendar),
                       today: now, calendar: calendar)
    }

    private func rate(_ pattern: WeekdayPattern, _ weekday: Int) -> Double? {
        pattern.entries.first { $0.weekday == weekday }?.hitRate
    }

    // MARK: - Order

    func testNowIsAMonday() {
        XCTAssertEqual(calendar().component(.weekday, from: now), 2)
    }

    func testEntriesStartOnTheCalendarsFirstWeekday() {
        let monday = pattern([:], calendar: calendar(firstWeekday: 2))
        XCTAssertEqual(monday.entries.map(\.weekday), [2, 3, 4, 5, 6, 7, 1])
        let sunday = pattern([:], calendar: calendar(firstWeekday: 1))
        XCTAssertEqual(sunday.entries.map(\.weekday), [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: - Window

    func testWindowIsTheFourWeeksBeforeToday() {
        let calendar = calendar()
        // Only today and the day just outside the window are met.
        let totals = [day(0, calendar): 1.0, day(29, calendar): 1.0]
        let pattern = pattern(totals, calendar: calendar)
        XCTAssertEqual(pattern.entries.map(\.hitRate), Array(repeating: 0, count: 7))
    }

    func testDaysBeforeCreationAreLeftOut() {
        let calendar = calendar()
        let pattern = pattern(totals(calendar: calendar), createdDaysAgo: 3, calendar: calendar)
        // Fri, Sat, Sun before Monday the 12th.
        XCTAssertEqual(pattern.entries.compactMap { $0.hitRate == nil ? nil : $0.weekday }, [6, 7, 1])
        XCTAssertEqual(rate(pattern, 6), 1)
        XCTAssertNil(rate(pattern, 2))
    }

    // MARK: - Hit rates + insight

    func testMissedSundaysAreTheWeakestDay() {
        let calendar = calendar()
        let totals = totals(calendar: calendar) { calendar.component(.weekday, from: $0) == 1 }
        let pattern = pattern(totals, calendar: calendar)
        XCTAssertEqual(rate(pattern, 1), 0)
        XCTAssertEqual(rate(pattern, 4), 1)
        XCTAssertEqual(pattern.weakestWeekday, 1)
    }

    func testNoInsightWhenTheGapIsUnderTwentyFivePoints() {
        let calendar = calendar()
        // One missed Wednesday → 75%, average ≈ 96% → gap ≈ 21 points.
        let totals = totals(calendar: calendar) { $0 == self.day(5, calendar) }
        let pattern = pattern(totals, calendar: calendar)
        XCTAssertEqual(rate(pattern, 4), 0.75)
        XCTAssertNil(pattern.weakestWeekday)
    }

    func testInsightAtFiftyPercent() {
        let calendar = calendar()
        // Two missed Wednesdays → 50%, average ≈ 93% → gap ≈ 43 points.
        let totals = totals(calendar: calendar) { [self.day(5, calendar), self.day(12, calendar)].contains($0) }
        XCTAssertEqual(pattern(totals, calendar: calendar).weakestWeekday, 4)
    }

    func testNoInsightWhenTwoWeekdaysTieForWeakest() {
        let calendar = calendar()
        let totals = totals(calendar: calendar) { [1, 7].contains(calendar.component(.weekday, from: $0)) }
        XCTAssertNil(pattern(totals, calendar: calendar).weakestWeekday)
    }

    func testNoInsightWithNothingToCompare() {
        let calendar = calendar()
        XCTAssertNil(pattern([:], createdDaysAgo: 0, calendar: calendar).weakestWeekday)
        XCTAssertNil(pattern([:], createdDaysAgo: 1, calendar: calendar).weakestWeekday)
    }

    func testNoInsightFromASingleDayPerWeekday() {
        let calendar = calendar()
        // Created two days ago: Sunday met, Saturday missed.
        let totals = [day(1, calendar): 1.0, day(2, calendar): 0]
        let pattern = pattern(totals, createdDaysAgo: 2, calendar: calendar)
        XCTAssertEqual(rate(pattern, 7), 0)
        XCTAssertNil(pattern.weakestWeekday)
    }

    func testInsightOnceEveryWeekdayIsSeenTwice() {
        let calendar = calendar()
        let totals = totals(calendar: calendar) { calendar.component(.weekday, from: $0) == 1 }
        // 13 days back: Sunday twice, Monday only once → still quiet.
        XCTAssertNil(pattern(totals, createdDaysAgo: 13, calendar: calendar).weakestWeekday)
        // 14 days back: every weekday twice → Sundays called out.
        XCTAssertEqual(pattern(totals, createdDaysAgo: 14, calendar: calendar).weakestWeekday, 1)
    }

    // MARK: - Fill

    func testFillOpacityLevels() {
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 1), 1)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0.99), 0.7)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0.75), 0.7)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0.74), 0.4)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0.5), 0.4)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0.25), 0.15)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: 0), 0.15)
        XCTAssertEqual(WeekdayPattern.fillOpacity(for: nil), 0.15)
    }
}
