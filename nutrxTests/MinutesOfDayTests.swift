import XCTest
@testable import nutrx

/// The time pickers' minutes after midnight as a date (`Calendar.date(atMinutes:on:)`): never nil. A new nutrient's
/// Reminders sheet crashed in 2.8 (244) when "At my usual time" was switched off: the picker read -1 minutes once more.
final class MinutesOfDayTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Chisinau")!
        return calendar
    }
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 15))! }

    private func hourMinute(_ date: Date) -> [Int] {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [parts.day!, parts.hour!, parts.minute!]
    }

    func testMinutesAfterMidnight() {
        XCTAssertEqual(hourMinute(calendar.date(atMinutes: 0, on: day)), [14, 0, 0])
        XCTAssertEqual(hourMinute(calendar.date(atMinutes: 9 * 60 + 30, on: day)), [14, 9, 30])
        XCTAssertEqual(hourMinute(calendar.date(atMinutes: 23 * 60 + 59, on: day)), [14, 23, 59])
    }

    /// -1 is "no time" (set times, or a stack without a reminder): midnight, not a crash.
    func testOutOfRangeMinutesStayOnTheDay() {
        XCTAssertEqual(hourMinute(calendar.date(atMinutes: -1, on: day)), [14, 0, 0])
        XCTAssertEqual(hourMinute(calendar.date(atMinutes: 24 * 60, on: day)), [14, 23, 59])
    }

    /// The day the clocks go forward: 3:30 doesn't exist in Chisinau on 29 March 2026, and there's still a date.
    func testASkippedHourStillGivesADate() {
        let springForward = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.date(atMinutes: 3 * 60 + 30,
                                                                            on: springForward)).day, 29)
    }
}
