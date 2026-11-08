import XCTest
@testable import nutrx

/// The paywall's plan line (#338, #352): hidden only while the selected plan's whole card is in view, between the
/// sheet's top and the footer's, `PlanLine.margin` above the pinned button.
final class PlanLineTests: XCTestCase {
    private let sheetTop: CGFloat = 62
    private let buttonTop: CGFloat = 602
    /// Where the footer and its hairline start.
    private var footerTop: CGFloat { buttonTop - PlanLine.margin }

    func testHiddenWhileTheWholeCardIsInView() {
        XCTAssertFalse(PlanLine.shows(card: 505...577, sheetTop: sheetTop, buttonTop: buttonTop))
    }

    /// #352: opened from Settings on an SE, Yearly ended at 597 with the footer at 592. Its middle was in view, so the
    /// line stayed hidden and nothing named the plan behind the footer.
    func testShowsOnceTheCardsBottomIsUnderTheFooter() {
        XCTAssertTrue(PlanLine.shows(card: 525...597, sheetTop: sheetTop, buttonTop: buttonTop))
    }

    func testTheFootersTopIsTheEdge() {
        XCTAssertFalse(PlanLine.shows(card: 500...footerTop, sheetTop: sheetTop, buttonTop: buttonTop))
        XCTAssertTrue(PlanLine.shows(card: 500...(footerTop + 1), sheetTop: sheetTop, buttonTop: buttonTop))
    }

    func testShowsOnceTheCardIsBehindTheButton() {
        XCTAssertTrue(PlanLine.shows(card: 585...657, sheetTop: sheetTop, buttonTop: buttonTop))
    }

    func testShowsOnceTheCardsTopHasScrolledAboveTheSheet() {
        XCTAssertTrue(PlanLine.shows(card: 40...112, sheetTop: sheetTop, buttonTop: buttonTop))
        XCTAssertFalse(PlanLine.shows(card: sheetTop...134, sheetTop: sheetTop, buttonTop: buttonTop))
    }

    /// Before the first measurement it stays hidden rather than flashing on for a frame.
    func testHiddenUntilMeasured() {
        XCTAssertFalse(PlanLine.shows(card: nil, sheetTop: sheetTop, buttonTop: buttonTop))
        XCTAssertFalse(PlanLine.shows(card: 585...657, sheetTop: sheetTop, buttonTop: nil))
    }
}
