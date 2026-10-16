import XCTest
@testable import nutrx

/// The words around a course (#99): the Duration row and the Finished section.
final class CourseTextTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func testSummary() {
        let text = CourseText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.summary(endDate: nil, now: day(10, 20)), "Ongoing")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 20, hour: 9)), "Until Sat 24 Oct · 5 days")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 24, hour: 9)), "Last day today")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 26)), "Ended 24 Oct")
        XCTAssertEqual(text.ended(day(10, 24)), "Ended 24 Oct")
    }
}
