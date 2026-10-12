import XCTest
@testable import nutrx

/// DESIGN.md §5.4, §5.5 — History strings.
final class HistoryTextTests: XCTestCase {
    private let enGB = Locale(identifier: "en_GB")

    func testDays() {
        XCTAssertEqual(HistoryText.days(1), "1 day")
        XCTAssertEqual(HistoryText.days(10), "10 days")
        XCTAssertEqual(HistoryText.days(0), "0 days")
    }

    func testGoalsLine() {
        XCTAssertEqual(HistoryText.goalsLine(met: 4, total: 6), "4 of 6 goals")
        XCTAssertEqual(HistoryText.goalsLine(met: 1, total: 1), "1 of 1 goal")
    }

    func testMissedLine() {
        XCTAssertEqual(HistoryText.missedLine(missedNames: [], goalCount: 6), "Every goal met")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["Omega-3"], goalCount: 6, locale: enGB), "Missed Omega-3")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["Omega-3", "Protein"], goalCount: 6, locale: enGB),
                       "Missed Omega-3 and Protein")
        XCTAssertEqual(HistoryText.missedLine(missedNames: ["A", "B", "C", "D"], goalCount: 6), "Missed 4 goals")
        XCTAssertEqual(HistoryText.missedLine(missedNames: [], goalCount: 0), "Nothing was tracked that day")
    }
}
