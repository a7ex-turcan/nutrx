import XCTest
@testable import nutrx

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
