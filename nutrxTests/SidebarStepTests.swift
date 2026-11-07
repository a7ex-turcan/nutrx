import XCTest
@testable import nutrx

final class SidebarStepTests: XCTestCase {
    private let order = ["Vitamin D", "Omega-3", "Magnesium"]

    func testMovesOneRow() {
        XCTAssertEqual(SidebarStep.next(in: order, from: "Omega-3", by: 1), "Magnesium")
        XCTAssertEqual(SidebarStep.next(in: order, from: "Omega-3", by: -1), "Vitamin D")
    }

    func testHoldsAtTheEnds() {
        XCTAssertEqual(SidebarStep.next(in: order, from: "Magnesium", by: 1), "Magnesium")
        XCTAssertEqual(SidebarStep.next(in: order, from: "Vitamin D", by: -1), "Vitamin D")
    }

    func testStartsAtAnEndWithNothingSelected() {
        XCTAssertEqual(SidebarStep.next(in: order, from: nil, by: 1), "Vitamin D")
        XCTAssertEqual(SidebarStep.next(in: order, from: nil, by: -1), "Magnesium")
    }

    /// A selection that's no longer a row (deleted, or in the Finished section while it's collapsed).
    func testStartsAtAnEndFromARowNoLongerShown() {
        XCTAssertEqual(SidebarStep.next(in: order, from: "Creatine", by: 1), "Vitamin D")
        XCTAssertEqual(SidebarStep.next(in: order, from: "Creatine", by: -1), "Magnesium")
    }

    func testNothingWithNoRows() {
        XCTAssertNil(SidebarStep.next(in: [String](), from: nil, by: 1))
        XCTAssertNil(SidebarStep.next(in: [String](), from: "Vitamin D", by: -1))
    }
}
