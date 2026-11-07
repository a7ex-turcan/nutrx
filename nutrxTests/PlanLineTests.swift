import XCTest
@testable import nutrx

final class PlanLineTests: XCTestCase {
    func testHiddenWhileTheCardIsInView() {
        XCTAssertFalse(PlanLine.shows(cardMidY: 535, sheetTop: 62, buttonTop: 603))
    }

    func testShowsOnceTheCardIsBehindTheButton() {
        XCTAssertTrue(PlanLine.shows(cardMidY: 621, sheetTop: 62, buttonTop: 603))
    }

    /// Within the margin above the button counts as behind it, the button's own padding.
    func testShowsWithinTheMarginAboveTheButton() {
        XCTAssertTrue(PlanLine.shows(cardMidY: 603 - PlanLine.margin, sheetTop: 62, buttonTop: 603))
        XCTAssertFalse(PlanLine.shows(cardMidY: 603 - PlanLine.margin - 1, sheetTop: 62, buttonTop: 603))
    }

    func testShowsOnceTheCardHasScrolledAboveTheSheet() {
        XCTAssertTrue(PlanLine.shows(cardMidY: 40, sheetTop: 62, buttonTop: 603))
        XCTAssertTrue(PlanLine.shows(cardMidY: 62, sheetTop: 62, buttonTop: 603))
    }

    /// Before the first measurement it stays hidden rather than flashing on for a frame.
    func testHiddenUntilMeasured() {
        XCTAssertFalse(PlanLine.shows(cardMidY: nil, sheetTop: 62, buttonTop: 603))
        XCTAssertFalse(PlanLine.shows(cardMidY: 621, sheetTop: 62, buttonTop: nil))
    }
}
