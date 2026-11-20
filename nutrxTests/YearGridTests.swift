import XCTest
@testable import nutrx

/// DESIGN.md §4.9a — History's year of full days.
final class YearGridTests: XCTestCase {
    private func calendar(firstWeekday: Int, timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 15))!
    }

    func testAYearOfWeeksEndingOnToday() {
        // Thursday 19 November 2026, Monday-first.
        let calendar = calendar(firstWeekday: 2)
        let today = date(2026, 11, 19, calendar)
        let grid = YearGrid(today: today, calendar: calendar)

        XCTAssertEqual(grid.weeks.count, 53)
        XCTAssertEqual(grid.today, calendar.startOfDay(for: today))
        let last = grid.weeks.last!
        XCTAssertEqual(last.start, calendar.startOfDay(for: date(2026, 11, 16, calendar)))
        // Monday to Thursday, then nothing after today.
        XCTAssertEqual(last.days.compactMap { $0 }.count, 4)
        XCTAssertEqual(last.days[3], grid.today)
        XCTAssertNil(last.days[4])
        // 52 whole weeks before it, starting on a Monday.
        XCTAssertEqual(grid.weeks.first!.start, calendar.startOfDay(for: date(2025, 11, 17, calendar)))
        XCTAssertTrue(grid.weeks.dropLast().allSatisfy { $0.days.allSatisfy { $0 != nil } })
        XCTAssertEqual(grid.days.count, 52 * 7 + 4)
        XCTAssertEqual(grid.days.last, grid.today)
    }

    func testRowsFollowTheFirstWeekday() {
        let monday = YearGrid(today: date(2026, 11, 19, calendar(firstWeekday: 2)), calendar: calendar(firstWeekday: 2))
        XCTAssertEqual(monday.weekdaySymbols, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(monday.labelledRows, [0, 2, 4])

        let sundayCalendar = calendar(firstWeekday: 1)
        let sunday = YearGrid(today: date(2026, 11, 19, sundayCalendar), calendar: sundayCalendar)
        XCTAssertEqual(sunday.weekdaySymbols.first, "Sun")
        XCTAssertEqual(sunday.labelledRows, [1, 3, 5])  // still Mon, Wed, Fri
        XCTAssertEqual(sunday.weeks.last!.start, calendar(firstWeekday: 1).startOfDay(for: date(2026, 11, 15, sundayCalendar)))
        XCTAssertEqual(sunday.weeks.last!.days.compactMap { $0 }.count, 5)
    }

    func testMonthLabelsSitOverTheWeekOfThe1st() {
        let calendar = calendar(firstWeekday: 2)
        let grid = YearGrid(today: date(2026, 11, 19, calendar), calendar: calendar)
        let labelled = grid.weeks.filter { $0.monthLabel != nil }
        // December 2025 to November 2026: twelve 1sts in the grid.
        XCTAssertEqual(labelled.map(\.monthLabel!),
                       ["Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov"])
        // 1 November 2026 is a Sunday: the week from Monday 26 October.
        XCTAssertEqual(labelled.last!.start, calendar.startOfDay(for: date(2026, 10, 26, calendar)))
    }

    func testAThe1stStillToComeHasNoLabel() {
        // Monday 30 November: the 1st of December is in this week, but after today.
        let calendar = calendar(firstWeekday: 2)
        let grid = YearGrid(today: date(2026, 11, 30, calendar), calendar: calendar)
        XCTAssertNil(grid.weeks.last!.monthLabel)
    }

    func testEveryDayIsOneCalendarDayAcrossTheClockChange() {
        // Europe/Chisinau springs forward on 29 March 2026: a 23-hour day, still one square.
        let calendar = calendar(firstWeekday: 2, timeZone: "Europe/Chisinau")
        let grid = YearGrid(today: date(2026, 4, 2, calendar), calendar: calendar)
        let days = grid.days
        XCTAssertEqual(Set(days).count, days.count)
        for (earlier, later) in zip(days, days.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: earlier, to: later).day, 1)
            XCTAssertEqual(later, calendar.startOfDay(for: later))
        }
    }

    func testTitleAndDayLine() {
        XCTAssertEqual(HistoryText.fullDaysInLastYear(0), "No full days in the last year")
        XCTAssertEqual(HistoryText.fullDaysInLastYear(1), "1 full day in the last year")
        XCTAssertEqual(HistoryText.fullDaysInLastYear(142), "142 full days in the last year")

        let calendar = calendar(firstWeekday: 2)
        let day = date(2026, 11, 3, calendar)
        let locale = Locale(identifier: "en_GB")
        XCTAssertTrue(HistoryText.yearDayLine(date: day, completion: .someMet, met: 3, total: 4, isToday: false,
                                              locale: locale).hasSuffix(" · 3 of 4 goals"))
        XCTAssertTrue(HistoryText.yearDayLine(date: day, completion: .someMet, met: 3, total: 4, isToday: false,
                                              locale: locale).contains("Tue"))
        XCTAssertEqual(HistoryText.yearDayLine(date: day, completion: .allMet, met: 2, total: 2, isToday: true),
                       "Today · 2 of 2 goals")
        XCTAssertTrue(HistoryText.yearDayLine(date: day, completion: .noEntries, met: 0, total: 3, isToday: false)
            .hasSuffix(" · Nothing logged"))
        XCTAssertTrue(HistoryText.yearDayLine(date: day, completion: .rest, met: 0, total: 0, isToday: false)
            .hasSuffix(" · Nothing due"))
    }

    func testOnlyAllMetDaysInTheYearCount() throws {
        // A log's day reads in the grid as on the calendar; the count is the all-met days.
        let calendar = calendar(firstWeekday: 2)
        let today = date(2026, 11, 19, calendar)
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 10, upperBound: nil,
                                       createdAt: date(2026, 1, 1, calendar), isRemoved: false)
        let day = { (offset: Int) in calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today)!) }
        let log = HistoryLog(nutrients: [nutrient],
                             totals: [day(1): [id: 10], day(2): [id: 4], day(3): [id: 12], day(400): [id: 10]],
                             today: today, calendar: calendar)
        let grid = YearGrid(today: today, calendar: calendar)
        let full = grid.days.filter { log.day($0).completion == .allMet }
        // Day 400 is before the grid's year.
        XCTAssertEqual(full, [day(3), day(1)])
        XCTAssertEqual(log.day(day(2)).completion, .noneMet)
    }
}
