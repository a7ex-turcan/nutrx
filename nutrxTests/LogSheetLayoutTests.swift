import XCTest
@testable import nutrx

/// The log sheet's amount shrinks to leave its unit whole (#242).
final class LogSheetLayoutTests: XCTestCase {
    func testAmountKeepsItsSizeWhenItFits() {
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 150, room: 160), 62)
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 160, room: 160), 62, "an exact fit")
    }

    func testAmountShrinksInProportion() {
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 200, room: 150), 46.5, accuracy: 1e-9)
    }

    func testAmountNeverShrinksBelowFortyPercent() {
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 50, textWidth: 1000, room: 100), 20, accuracy: 1e-9)
    }

    func testNothingMeasuredOrNoRoomKeepsTheSize() {
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 0, room: 100), 62, "not measured yet")
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 150, room: 0), 62, "the sheet not measured yet")
        XCTAssertEqual(LogSheet.fittedAmountSize(base: 62, textWidth: 150, room: -20), 62)
    }
}
