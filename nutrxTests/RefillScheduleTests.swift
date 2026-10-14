import XCTest
@testable import nutrx

/// Refill reminders: one per bottle at 10:00 on the threshold day (or the next 10:00 when already low), never twice,
/// snooze, and the words.
final class RefillScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    /// 2026-10-14 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_979_200)
    private let refilled = Date(timeIntervalSince1970: 1_789_387_200)  // 2026-09-14 12:00 UTC

    private func status(level: SupplySchedule.Level, daysLeft: Int?, reminder: Int = 7,
                        refilledAt: Date? = nil) -> SupplySchedule.Status {
        .init(setup: .init(servings: 120, servingAmount: 1000, refilledAt: refilledAt ?? refilled, reminderDays: reminder),
              remaining: Double(daysLeft ?? 0) * 2000, dailyUse: daysLeft == nil ? nil : 2000, daysLeft: daysLeft,
              level: level)
    }

    private func tenAM(_ dayOffset: Int) -> Date {
        calendar.date(bySettingHour: 10, minute: 0, second: 0,
                      of: calendar.date(byAdding: .day, value: dayOffset, to: now)!)!
    }

    func testFiresOnTheThresholdDayAtTen() {
        let fire = RefillSchedule.fireDate(status: status(level: .plenty, daysLeft: 20), previous: nil, now: now,
                                           calendar: calendar)
        XCTAssertEqual(fire, tenAM(13), "20 days left, reminder at 7: in 13 days")
    }

    func testAlreadyLowOrOutFiresAtTheNextTen() {
        // It's 12:00, so today's 10:00 has passed: tomorrow.
        XCTAssertEqual(RefillSchedule.fireDate(status: status(level: .low, daysLeft: 3), previous: nil, now: now,
                                               calendar: calendar), tenAM(1))
        XCTAssertEqual(RefillSchedule.fireDate(status: status(level: .out, daysLeft: 0), previous: nil, now: now,
                                               calendar: calendar), tenAM(1))
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        XCTAssertEqual(RefillSchedule.fireDate(status: status(level: .low, daysLeft: 3), previous: nil, now: morning,
                                               calendar: calendar), tenAM(0))
    }

    func testNoReminderWithoutAnEstimate() {
        XCTAssertNil(RefillSchedule.fireDate(status: status(level: .noHistory, daysLeft: nil), previous: nil, now: now,
                                             calendar: calendar))
    }

    func testNeverTwiceForTheSameBottle() {
        let fired = RefillSchedule.State(refilledAt: refilled, fireDate: now.addingTimeInterval(-3600))
        XCTAssertNil(RefillSchedule.fireDate(status: status(level: .low, daysLeft: 2), previous: fired, now: now,
                                             calendar: calendar))
        // A new bottle starts over.
        let newBottle = status(level: .low, daysLeft: 2, refilledAt: now.addingTimeInterval(-60))
        XCTAssertNotNil(RefillSchedule.fireDate(status: newBottle, previous: fired, now: now, calendar: calendar))
    }

    func testPendingRemindersFollowTheEstimateUnlessSnoozed() {
        let pending = RefillSchedule.State(refilledAt: refilled, fireDate: tenAM(20))
        XCTAssertEqual(RefillSchedule.fireDate(status: status(level: .plenty, daysLeft: 10), previous: pending, now: now,
                                               calendar: calendar), tenAM(3), "use picked up: earlier")
        let snoozed = RefillSchedule.snoozed(status(level: .low, daysLeft: 3), now: now)
        XCTAssertEqual(snoozed.fireDate, now.addingTimeInterval(86_400))
        XCTAssertEqual(RefillSchedule.fireDate(status: status(level: .low, daysLeft: 3), previous: snoozed, now: now,
                                               calendar: calendar), now.addingTimeInterval(86_400))
    }

    func testDaysAtFire() {
        XCTAssertEqual(RefillSchedule.daysAtFire(status: status(level: .plenty, daysLeft: 20), fireDate: tenAM(13),
                                                 now: now, calendar: calendar), 7)
        XCTAssertEqual(RefillSchedule.daysAtFire(status: status(level: .low, daysLeft: 3), fireDate: tenAM(1),
                                                 now: now, calendar: calendar), 2)
    }

    func testWords() {
        XCTAssertEqual(RefillSchedule.title(name: "Vitamin D", daysAtFire: 7, isOut: false), "Vitamin D runs out in about a week")
        XCTAssertEqual(RefillSchedule.title(name: "Vitamin D", daysAtFire: 3, isOut: false), "Vitamin D runs out in about 3 days")
        XCTAssertEqual(RefillSchedule.title(name: "Vitamin D", daysAtFire: 1, isOut: false), "Vitamin D runs out tomorrow")
        XCTAssertEqual(RefillSchedule.title(name: "Vitamin D", daysAtFire: 0, isOut: false), "Vitamin D runs out today")
        XCTAssertEqual(RefillSchedule.title(name: "Vitamin D", daysAtFire: 0, isOut: true), "Vitamin D has run out")
        XCTAssertEqual(RefillSchedule.body(daysAtFire: 6, isOut: false),
                       "About 6 days left at your usual amount. Tap Refilled when you open a new bottle.")
        XCTAssertEqual(RefillSchedule.body(daysAtFire: 0, isOut: true), "Out of supply. Tap Refilled when you open a new bottle.")
    }

    func testDoseRemindersShareWhatsLeftOfTheBudget() {
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 4), 14)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 4, budget: 60 - 5), 13)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 6, budget: 60 - 3), 9)
    }
}
