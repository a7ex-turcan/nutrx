import XCTest
@testable import nutrx

/// DESIGN.md §4.9, §5.4, §5.5 — which nutrients count on a past day, and how the day reads.
final class HistoryLogTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Monday 12 October 2026, midday.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12))! }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
    }

    private let vitaminD = UUID(), omega = UUID(), caffeine = UUID(), removed = UUID()

    private func nutrients(createdDaysAgo: Int = 30) -> [HistoryNutrient] {
        [
            HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil,
                            createdAt: day(createdDaysAgo), isDeleted: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 2000, upperBound: nil,
                            createdAt: day(createdDaysAgo), isDeleted: false),
            HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil,
                            createdAt: day(createdDaysAgo), isDeleted: false),
            HistoryNutrient(id: removed, goalType: .minimum, target: 1, upperBound: nil,
                            createdAt: day(createdDaysAgo), isDeleted: true),
        ]
    }

    private func log(_ totals: [Int: [UUID: Double]], nutrients: [HistoryNutrient]? = nil,
                     exclusions: [Int: Set<UUID>] = [:]) -> HistoryLog {
        HistoryLog(nutrients: nutrients ?? self.nutrients(),
                   totals: Dictionary(uniqueKeysWithValues: totals.map { (day($0.key), $0.value) }),
                   exclusions: Dictionary(uniqueKeysWithValues: exclusions.map { (day($0.key), $0.value) }),
                   today: now, calendar: calendar)
    }

    // MARK: - Counting

    func testEveryActiveNutrientCountsEvenWithoutEntries() {
        let result = log([1: [vitaminD: 4000]]).day(day(1))
        XCTAssertEqual(result.goals.map(\.nutrientID), [vitaminD, omega, caffeine])
        XCTAssertEqual(result.goals.map(\.isMet), [true, false, true])  // nothing logged for omega; caffeine at 0 is within its limit
        XCTAssertEqual(result.metCount, 2)
        XCTAssertEqual(result.completion, .someMet)
    }

    func testRemovedNutrientsDontCountButStillShowWhenLogged() {
        let result = log([1: [vitaminD: 4000, omega: 2000, removed: 5]]).day(day(1))
        XCTAssertFalse(result.goals.map(\.nutrientID).contains(removed))
        XCTAssertEqual(result.otherLogged.map(\.nutrientID), [removed])
        XCTAssertEqual(result.otherLogged.first?.total, 5)
        XCTAssertEqual(result.completion, .allMet)
    }

    func testNutrientsCreatedLaterDontCount() {
        var nutrients = nutrients()
        nutrients[1] = HistoryNutrient(id: omega, goalType: .minimum, target: 2000, upperBound: nil,
                                       createdAt: day(1), isDeleted: false)
        let result = log([2: [vitaminD: 4000]], nutrients: nutrients).day(day(2))
        XCTAssertEqual(result.goals.map(\.nutrientID), [vitaminD, caffeine])
        XCTAssertEqual(result.completion, .allMet)
    }

    func testExcludedNutrientsDontCountThatDay() {
        let result = log([1: [vitaminD: 4000, omega: 500]], exclusions: [1: [omega]]).day(day(1))
        XCTAssertEqual(result.goals.map(\.nutrientID), [vitaminD, caffeine])
        XCTAssertEqual(result.otherLogged.map(\.nutrientID), [omega])
        XCTAssertEqual(result.completion, .allMet)
    }

    func testNegativeTotalsFloorAtZero() {
        let result = log([1: [omega: -300]]).day(day(1))
        XCTAssertEqual(result.goals.first { $0.nutrientID == omega }?.total, 0)
    }

    // MARK: - Completion

    func testADayWithNothingLoggedHasNoEntries() {
        // Caffeine would count as met at 0, but a blank day stays blank (as for streaks).
        XCTAssertEqual(log([:]).day(day(3)).completion, .noEntries)
    }

    func testLoggedButNothingMetIsNoneMet() {
        let atLeastOnly = nutrients().filter { $0.goalType == .minimum && !$0.isDeleted }
        XCTAssertEqual(log([1: [vitaminD: 100]], nutrients: atLeastOnly).day(day(1)).completion, .noneMet)
    }

    func testOverTheLimitIsMissed() {
        let result = log([1: [vitaminD: 4000, omega: 2000, caffeine: 500]]).day(day(1))
        XCTAssertEqual(result.goals.last?.isMet, false)
        XCTAssertEqual(result.completion, .someMet)
    }

    // MARK: - Recent days

    func testRecentDaysAreCompletedDaysWithEntriesNewestFirst() {
        let log = log([0: [vitaminD: 1], 1: [vitaminD: 1], 3: [omega: 1], 4: [omega: 1], 9: [omega: 1]])
        XCTAssertEqual(log.recentDays(limit: 3).map(\.date), [day(1), day(3), day(4)])
        XCTAssertTrue(log.hasPastEntries)
    }

    func testOnlyTodayLoggedMeansNoPastEntries() {
        XCTAssertFalse(log([0: [vitaminD: 1]]).hasPastEntries)
    }

    func testFirstDayIsTheEarliestEntryOrNutrient() {
        XCTAssertEqual(log([40: [vitaminD: 1]]).firstDay, day(40))
        XCTAssertEqual(log([2: [vitaminD: 1]]).firstDay, day(30))
    }
}

/// DESIGN.md §4.9 — the calendar's month layout.
final class MonthGridTests: XCTestCase {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 15))!
    }

    func testOctober2026MondayFirst() {
        // 1 October 2026 is a Thursday → three blanks before it on a Monday-first grid (the mockup).
        let calendar = calendar(firstWeekday: 2)
        let grid = MonthGrid(containing: date(2026, 10, 12, calendar), calendar: calendar)
        XCTAssertEqual(grid.leadingBlanks, 3)
        XCTAssertEqual(grid.days.count, 31)
        XCTAssertEqual(grid.days.first, calendar.startOfDay(for: date(2026, 10, 1, calendar)))
        XCTAssertEqual(grid.weekdaySymbols, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(grid.narrowWeekdaySymbols, ["M", "T", "W", "T", "F", "S", "S"])
    }

    func testOctober2026SundayFirst() {
        let calendar = calendar(firstWeekday: 1)
        let grid = MonthGrid(containing: date(2026, 10, 12, calendar), calendar: calendar)
        XCTAssertEqual(grid.leadingBlanks, 4)
        XCTAssertEqual(grid.weekdaySymbols.first, "Sun")
    }

    func testMonthThatStartsOnTheFirstWeekdayHasNoBlanks() {
        // 1 June 2026 is a Monday.
        let calendar = calendar(firstWeekday: 2)
        XCTAssertEqual(MonthGrid(containing: date(2026, 6, 20, calendar), calendar: calendar).leadingBlanks, 0)
    }

    func testFebruaryInALeapYear() {
        let calendar = calendar(firstWeekday: 2)
        XCTAssertEqual(MonthGrid(containing: date(2028, 2, 10, calendar), calendar: calendar).days.count, 29)
    }

    func testMovingAcrossAYear() {
        let calendar = calendar(firstWeekday: 2)
        let january = MonthGrid(containing: date(2027, 1, 5, calendar), calendar: calendar)
        let december = january.moved(by: -1, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: december.month), 12)
        XCTAssertEqual(calendar.component(.year, from: december.month), 2026)
        XCTAssertTrue(december.contains(date(2026, 12, 31, calendar), calendar: calendar))
        XCTAssertFalse(december.contains(date(2027, 1, 1, calendar), calendar: calendar))
    }
}

/// DESIGN.md §5.4, §5.5 — History strings.
final class HistoryTextTests: XCTestCase {
    private let enGB = Locale(identifier: "en_GB")

    func testDays() {
        XCTAssertEqual(HistoryText.days(1), "1 day")
        XCTAssertEqual(HistoryText.days(10), "10 days")
        XCTAssertEqual(HistoryText.days(0), "0 days")
    }

    func testGoalsLine() {
        XCTAssertEqual(HistoryText.goalsLine(met: 4, total: 6), "4 of 6 goals")
        XCTAssertEqual(HistoryText.goalsLine(met: 1, total: 1), "1 of 1 goal")
    }

    func testMissedLine() {
        XCTAssertEqual(HistoryText.missedLine(missedNames: [], goalCount: 6), "Every goal met")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["Omega-3"], goalCount: 6, locale: enGB), "Missed Omega-3")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["Omega-3", "Protein"], goalCount: 6, locale: enGB),
                       "Missed Omega-3 and Protein")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["A", "B", "C", "D"], goalCount: 6), "Missed 4 goals")
        XCTAssertEqual(HistoryText.missedLine(missedNames: [], goalCount: 0), "Nothing was tracked that day")
    }
}
