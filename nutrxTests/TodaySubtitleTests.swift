import XCTest
@testable import nutrx

/// Today's date under the title (#360): the full date, or a short one at accessibility sizes.
final class TodaySubtitleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Wednesday 30 September 2026: the longest weekday and month.
    private var longest: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12))!
    }

    func testTheFullDateBelowAccessibilitySizes() {
        let text = TodaySubtitle.text(for: longest, isAccessibilitySize: false, locale: Locale(identifier: "en_GB"),
                                      calendar: calendar)
        XCTAssertTrue(text.contains("Wednesday"), text)
        XCTAssertTrue(text.contains("September"), text)
        XCTAssertTrue(text.contains("30"), text)
    }

    func testAShortDateAtAccessibilitySizes() {
        for identifier in ["en_GB", "en_US"] {
            let text = TodaySubtitle.text(for: longest, isAccessibilitySize: true, locale: Locale(identifier: identifier),
                                          calendar: calendar)
            XCTAssertTrue(text.contains("Wed"), text)
            XCTAssertFalse(text.contains("Wednesday"), text)
            XCTAssertTrue(text.contains("Sep"), text)
            XCTAssertFalse(text.contains("September"), text)
            // About half the full date: the full one ran out of room at about 19 characters on an iPhone 17 at AX5.
            XCTAssertLessThanOrEqual(text.count, 11, text)
        }
    }
}
