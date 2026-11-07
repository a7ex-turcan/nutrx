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
                            createdAt: day(createdDaysAgo), isRemoved: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 2000, upperBound: nil,
                            createdAt: day(createdDaysAgo), isRemoved: false),
            HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil,
                            createdAt: day(createdDaysAgo), isRemoved: false),
            HistoryNutrient(id: removed, goalType: .minimum, target: 1, upperBound: nil,
                            createdAt: day(createdDaysAgo), isRemoved: true),
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
                                       createdAt: day(1), isRemoved: false)
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
        let atLeastOnly = nutrients().filter { $0.goalType == .minimum && !$0.isRemoved }
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

    func testEntriesTodayAreEnoughToExportButNotForHistory() {
        let today = Calendar.current.startOfDay(for: .now)
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: today,
                                       isRemoved: false)
        let onlyToday = HistoryLog(nutrients: [nutrient], totals: [today: [id: 1]], today: today, calendar: .current)
        XCTAssertTrue(onlyToday.hasEntries, "Export data's All time includes today (#103)")
        XCTAssertFalse(onlyToday.hasPastEntries)
        let empty = HistoryLog(nutrients: [nutrient], totals: [:], today: today, calendar: .current)
        XCTAssertFalse(empty.hasEntries)
    }

    // MARK: - Dose plans (#135)

    /// Vitamin D at 2,000 IU for 5 days from 10 days ago, then 4,000 IU for 5 (kept), with 1,000 IU pinned before it.
    private func planned() -> [HistoryNutrient] {
        var list = nutrients()
        list[0].dosePlan = NutrientDosePlan().creating(
            steps: [.init(goal: NutrientGoal(target: 2000), days: 5), .init(goal: NutrientGoal(target: 4000), days: 5)],
            end: .keep, start: day(10), base: NutrientGoal(target: 1000), today: day(10), calendar: calendar)
        return list
    }

    func testEachDayIsJudgedByItsOwnGoal() throws {
        let log = log([12: [vitaminD: 1000], 8: [vitaminD: 2000], 3: [vitaminD: 2000]], nutrients: planned())
        func vitaminDGoal(_ offset: Int) throws -> HistoryDay.Goal {
            try XCTUnwrap(log.day(day(offset)).goals.first { $0.nutrientID == vitaminD })
        }
        XCTAssertEqual(try vitaminDGoal(12).goal, NutrientGoal(target: 1000), "before the plan: the goal it pinned")
        XCTAssertTrue(try vitaminDGoal(12).isMet)
        XCTAssertEqual(try vitaminDGoal(8).goal, NutrientGoal(target: 2000), "the first step")
        XCTAssertTrue(try vitaminDGoal(8).isMet)
        XCTAssertEqual(try vitaminDGoal(3).goal, NutrientGoal(target: 4000), "the second step")
        XCTAssertFalse(try vitaminDGoal(3).isMet)
        XCTAssertEqual(log.day(day(3)).goals.first { $0.nutrientID == omega }?.goal, NutrientGoal(target: 2000),
                       "no plan: the base goal")
    }
}
