import XCTest
@testable import nutrx

/// DESIGN.md §4.3 — "Vitamin D at 13:00" on the day-score card.
final class UpcomingReminderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        return calendar
    }

    private func time(_ hour: Int, _ minute: Int = 0, day: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testPicksTheEarliestReminderLaterToday() {
        let next = UpcomingReminder.next(
            after: time(10),
            among: [("Magnesium", time(21)), ("Vitamin D", time(13)), ("Omega-3", time(8))],
            calendar: calendar
        )
        XCTAssertEqual(next, UpcomingReminder(nutrientName: "Vitamin D", time: time(13)))
    }

    func testUsesOnlyTheTimeOfDayOfStoredReminders() {
        // Reminders are stored with an arbitrary date; only hour and minute matter.
        let next = UpcomingReminder.next(after: time(10), among: [("Vitamin D", time(13, 30, day: 1))], calendar: calendar)
        XCTAssertEqual(next?.time, time(13, 30))
    }

    func testReminderAtExactlyNowIsNotUpcoming() {
        XCTAssertNil(UpcomingReminder.next(after: time(13), among: [("Vitamin D", time(13))], calendar: calendar))
    }

    func testNothingLeftTodayIsNil() {
        XCTAssertNil(UpcomingReminder.next(after: time(22), among: [("Vitamin D", time(13))], calendar: calendar))
        XCTAssertNil(UpcomingReminder.next(after: time(9), among: [], calendar: calendar))
    }
}
