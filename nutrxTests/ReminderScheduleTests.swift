import XCTest
@testable import nutrx

/// #4 — dose reminders as one-off requests per date: logging silences only the rest of today.
final class ReminderScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Chisinau")!
        return calendar
    }
    private let vitaminD = UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!
    private let magnesium = UUID(uuidString: "00000000-0000-0000-0000-00000000000E")!

    /// 13 October 2026 at `hour`:00 in the test calendar.
    private func date(day: Int = 13, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func plan(_ id: UUID, hours: [Int], loggedToday: Bool = false) -> ReminderSchedule.Plan {
        ReminderSchedule.Plan(nutrientID: id, times: hours.map { .init(hour: $0, minute: 0) }, loggedToday: loggedToday)
    }

    func testTheWindowShrinksToStayUnderTheBudget() {
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 0), 0)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 1), 14)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 4), 14)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 5), 12)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 60), 1)
        XCTAssertEqual(ReminderSchedule.days(forReminderCount: 100), 1)  // today only, rather than nothing
    }

    func testTodaysPassedTimesAreLeftOutAndLaterOnesKept() {
        let occurrences = ReminderSchedule.occurrences(for: [plan(vitaminD, hours: [9, 21])], now: date(hour: 12),
                                                       calendar: calendar)
        let today = occurrences.filter { calendar.isDate($0.fireDate, inSameDayAs: date(hour: 12)) }
        XCTAssertEqual(today.map(\.fireDate), [date(hour: 21)])
        // 14 days (60 / 2 = 30, capped at maxDays), minus 09:00 today.
        XCTAssertEqual(occurrences.count, 14 * 2 - 1)
    }

    func testWeekendsCanHaveTheirOwnTime() {
        // A usual time learned apart for weekends (#137): 8:30 on weekdays, 10:15 on Saturday 17 and Sunday 18.
        let usual = ReminderSchedule.Plan(nutrientID: vitaminD, times: [.init(minutes: 510)], loggedToday: false,
                                          weekendTimes: [.init(minutes: 615)])
        let fires = ReminderSchedule.occurrences(for: [usual], now: date(hour: 12), calendar: calendar).map(\.fireDate)
        XCTAssertTrue(fires.contains(date(day: 16, hour: 8, minute: 30)), "Friday")
        XCTAssertTrue(fires.contains(date(day: 17, hour: 10, minute: 15)), "Saturday")
        XCTAssertTrue(fires.contains(date(day: 18, hour: 10, minute: 15)), "Sunday")
        XCTAssertTrue(fires.contains(date(day: 19, hour: 8, minute: 30)), "Monday")
        XCTAssertFalse(fires.contains(date(day: 17, hour: 8, minute: 30)))
        XCTAssertEqual(ReminderSchedule.Time(minutes: 615), ReminderSchedule.Time(hour: 10, minute: 15))
    }

    func testAStacksReminderOnlyOnItsDueDaysWithItsOwnIdentifiers() {
        // A stack (#137): one a day at 9:00, only on the days something in it is due (here the 14th and 16th).
        let morning = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let due: Set<Date> = [calendar.startOfDay(for: date(day: 14, hour: 0)), calendar.startOfDay(for: date(day: 16, hour: 0))]
        let stack = ReminderSchedule.Plan(nutrientID: morning, times: [.init(hour: 9, minute: 0)], loggedToday: false,
                                          dueDays: due, isStack: true)
        let occurrences = ReminderSchedule.occurrences(for: [stack], now: date(hour: 12), calendar: calendar)
        XCTAssertEqual(occurrences.map(\.fireDate), [date(day: 14, hour: 9), date(day: 16, hour: 9)])
        XCTAssertEqual(occurrences.first?.id, "stack-00000000-0000-0000-0000-0000000000AA-reminder-0900-20261014")
    }

    func testLoggingSilencesOnlyTheRestOfToday() {
        let occurrences = ReminderSchedule.occurrences(for: [plan(vitaminD, hours: [9, 21], loggedToday: true)],
                                                       now: date(hour: 12), calendar: calendar)
        XCTAssertFalse(occurrences.contains { calendar.isDate($0.fireDate, inSameDayAs: date(hour: 12)) })
        // Tomorrow and after are untouched.
        XCTAssertTrue(occurrences.contains { $0.fireDate == date(day: 14, hour: 9) })
        XCTAssertTrue(occurrences.contains { $0.fireDate == date(day: 14, hour: 21) })
        XCTAssertEqual(occurrences.count, 13 * 2)
    }

    func testNutrientsShareTheBudget() {
        // 6 reminders a day → 10 days, for both nutrients alike.
        let plans = [plan(vitaminD, hours: [7, 9, 11, 13]), plan(magnesium, hours: [20, 22])]
        let occurrences = ReminderSchedule.occurrences(for: plans, now: date(hour: 0), calendar: calendar)
        XCTAssertEqual(occurrences.count, 60)
        XCTAssertLessThanOrEqual(occurrences.count, ReminderSchedule.budget)
        XCTAssertEqual(occurrences.filter { $0.nutrientID == magnesium }.map(\.fireDate).max(), date(day: 22, hour: 22))
    }

    func testIdentifiersCarryTheNutrientTimeAndDateAndAreUnique() {
        let occurrences = ReminderSchedule.occurrences(for: [plan(vitaminD, hours: [9])], now: date(hour: 8),
                                                       calendar: calendar)
        XCTAssertEqual(occurrences.first?.id, "nutrient-00000000-0000-0000-0000-00000000000D-reminder-0900-20261013")
        XCTAssertEqual(Set(occurrences.map(\.id)).count, occurrences.count)
        XCTAssertTrue(occurrences.allSatisfy { $0.id.hasPrefix(ReminderSchedule.prefix(nutrientID: self.vitaminD)) })
    }

    func testMinutesAreKept() {
        let plans = [ReminderSchedule.Plan(nutrientID: vitaminD, times: [.init(hour: 8, minute: 45)], loggedToday: false)]
        let first = ReminderSchedule.occurrences(for: plans, now: date(hour: 8), calendar: calendar).first
        XCTAssertEqual(first?.fireDate, date(hour: 8, minute: 45))
        XCTAssertEqual(first?.id.contains("-0845-20261013"), true)
    }

    func testNoRemindersNoOccurrences() {
        XCTAssertTrue(ReminderSchedule.occurrences(for: [], now: date(hour: 8), calendar: calendar).isEmpty)
    }
}
