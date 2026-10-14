import XCTest
import SwiftData
@testable import nutrx

/// Supply & refills: what's left, daily use, days left and the level, including partial servings, decrements and
/// deleted records.
final class SupplyScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    /// 2026-10-14 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_979_200)

    private func day(_ offset: Int, hour: Int = 9) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .hour, value: offset * 24 + hour, to: start)!
    }

    /// 120 softgels of 1,000 IU, refilled `refilled` days ago, reminder at 7 days.
    private func setup(servings: Double = 120, serving: Double = 1000, refilled: Int = -30,
                       reminder: Int = 7) -> SupplySchedule.Setup {
        .init(servings: servings, servingAmount: serving, refilledAt: day(refilled, hour: 0), reminderDays: reminder)
    }

    /// `amount` logged every day from `from` days ago through today.
    private func daily(_ amount: Double, from: Int) -> [SupplySchedule.Log] {
        (from...0).map { SupplySchedule.Log(date: day($0), amount: amount) }
    }

    func testRemainingIsTheBottleMinusWhatsLoggedSinceTheRefill() {
        let logs = daily(2000, from: -9)  // 10 days × 2,000 IU since a refill 30 days ago
        let status = SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(status.remaining, 100_000)
        XCTAssertEqual(status.servingsLeft, 100)
        XCTAssertEqual(status.dailyUse, 2000)
        XCTAssertEqual(status.daysLeft, 50)
        XCTAssertEqual(status.level, .plenty)
    }

    func testLogsBeforeTheRefillDontCount() {
        let logs = daily(2000, from: -9)
        let status = SupplySchedule.status(setup: setup(refilled: -2), logs: logs, now: now, calendar: calendar)
        // Refilled at the start of 2 days ago: that day, yesterday and today count.
        XCTAssertEqual(status.remaining, 120_000 - 6000)
        XCTAssertEqual(status.dailyUse, 2000, "daily use isn't reset by a refill")
    }

    func testLowAtOrUnderTheReminderThreshold() {
        // 114 of 120 servings used: 6,000 IU left at 2,000 a day = 3 days.
        let logs = daily(2000, from: -13) + [SupplySchedule.Log(date: day(-20), amount: 86_000)]
        let status = SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(status.remaining, 6000)
        XCTAssertEqual(status.daysLeft, 3)
        XCTAssertEqual(status.level, .low)

        let atThreshold = SupplySchedule.status(setup: setup(reminder: 3), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(atThreshold.level, .low, "exactly at the threshold counts as low")
        let under = SupplySchedule.status(setup: setup(reminder: 2), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(under.level, .plenty)
    }

    func testOutWhenLessThanAFifthOfAServingIsLeft() {
        let logs = [SupplySchedule.Log(date: day(-1), amount: 119_900)]
        let status = SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(status.level, .out)
        XCTAssertEqual(status.servingsLeft, 0)
        let overdrawn = SupplySchedule.status(setup: setup(), logs: [.init(date: day(-1), amount: 500_000)],
                                              now: now, calendar: calendar)
        XCTAssertEqual(overdrawn.remaining, 0, "never below zero")
        XCTAssertEqual(overdrawn.level, .out)
    }

    func testDecrementsCountBackInButNeverPastAFullBottle() {
        let logs = [SupplySchedule.Log(date: day(-1), amount: 3000), .init(date: day(-1), amount: -1000)]
        XCTAssertEqual(SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar).remaining, 118_000)
        let undoneMore = [SupplySchedule.Log(date: day(-1), amount: -5000)]
        XCTAssertEqual(SupplySchedule.status(setup: setup(), logs: undoneMore, now: now, calendar: calendar).remaining,
                       120_000)
    }

    func testPartialServingsRoundDown() {
        let logs = [SupplySchedule.Log(date: day(-1), amount: 1500)]  // a serving and a half
        let status = SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(status.remaining, 118_500)
        XCTAssertEqual(status.servingsLeft, 118)
    }

    func testNoEstimateWithFewerThanThreeDaysOfLogging() {
        let twoDays = daily(2000, from: -1)
        let status = SupplySchedule.status(setup: setup(), logs: twoDays, now: now, calendar: calendar)
        XCTAssertNil(status.dailyUse)
        XCTAssertNil(status.daysLeft)
        XCTAssertEqual(status.level, .noHistory)
        XCTAssertNotNil(SupplySchedule.averageDailyUse(logs: daily(2000, from: -2), now: now, calendar: calendar))
    }

    func testDailyUseOnlyLooksAtTheLastFourteenDays() {
        let old = daily(10_000, from: -40).filter { $0.date < day(-20) }
        let recent = daily(1000, from: -13)
        XCTAssertEqual(SupplySchedule.averageDailyUse(logs: old + recent, now: now, calendar: calendar), 1000)
        XCTAssertNil(SupplySchedule.averageDailyUse(logs: old, now: now, calendar: calendar), "nothing recent")
    }

    func testDaysWithoutLogsLowerTheAverage() {
        // Logged 3,000 on day −5 and 3,000 today: 6,000 over 6 days.
        let logs = [SupplySchedule.Log(date: day(-5), amount: 3000), .init(date: day(0), amount: 3000)]
        XCTAssertEqual(SupplySchedule.averageDailyUse(logs: logs, now: now, calendar: calendar), 1000)
    }

    func testGaugeAndThreshold() {
        let logs = daily(2000, from: -9)
        let status = SupplySchedule.status(setup: setup(), logs: logs, now: now, calendar: calendar)
        XCTAssertEqual(status.fractionLeft, 100_000.0 / 120_000.0, accuracy: 1e-9)
        XCTAssertEqual(status.thresholdFraction ?? 0, 14_000.0 / 120_000.0, accuracy: 1e-9)
    }

    func testDaysInABottle() {
        XCTAssertEqual(SupplySchedule.daysInBottle(servings: 120, servingAmount: 1000, dailyAmount: 2000), 60)
        XCTAssertNil(SupplySchedule.daysInBottle(servings: 120, servingAmount: 1000, dailyAmount: 0))
    }

    @MainActor
    func testANutrientsSupplyUsesItsOwnRecordsAndServingDefaultsToAStep() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        context.insert(vitaminD)
        XCTAssertNil(vitaminD.supplyStatus(now: now), "not set")
        vitaminD.supplyServings = 120
        vitaminD.supplyRefilledAt = day(-5, hour: 0)
        XCTAssertEqual(vitaminD.effectiveServingAmount, 1000)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 2000, date: day(-1)))
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 2000, date: day(-10)))  // before the refill
        try context.save()
        XCTAssertEqual(vitaminD.supplyStatus(now: now)?.remaining, 118_000)

        vitaminD.refillSupply(now: now)
        XCTAssertEqual(vitaminD.supplyStatus(now: now)?.remaining, 120_000)
    }
}
