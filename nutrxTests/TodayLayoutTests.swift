import XCTest
@testable import nutrx

final class TodayLayoutTests: XCTestCase {
    func testLayoutByWidth() {
        XCTAssertEqual(TodayLayout.of(width: 402, isAccessibilitySize: false), .list, "iPhone")
        XCTAssertEqual(TodayLayout.of(width: 834, isAccessibilitySize: false), .columns, "11-inch iPad, portrait")
        XCTAssertEqual(TodayLayout.of(width: 1032, isAccessibilitySize: false), .columns,
                       "13-inch iPad, portrait: wide, but too narrow for the side column")
        XCTAssertEqual(TodayLayout.of(width: 1123, isAccessibilitySize: false), .columns)
        XCTAssertEqual(TodayLayout.of(width: 1124, isAccessibilitySize: false), .sideColumn)
        XCTAssertEqual(TodayLayout.of(width: 1210, isAccessibilitySize: false), .sideColumn, "11-inch iPad, landscape")
        XCTAssertEqual(TodayLayout.of(width: 1376, isAccessibilitySize: false), .sideColumn, "13-inch iPad, landscape")
    }

    func testTheLargestTextSizesKeepTheList() {
        XCTAssertEqual(TodayLayout.of(width: 1376, isAccessibilitySize: true), .list)
    }

    func testTheSideColumnLeavesCardsTheirMinimum() {
        XCTAssertEqual(TodayLayout.sideColumnMinimum, 1124)
        let cards = (TodayLayout.sideColumnMinimum - 2 * 40 - TodayLayout.sideColumnWidth - 24 - 20) / 2
        XCTAssertEqual(cards, TodayLayout.minimumCardWidth)
    }

    func testTheAnchorIsTheFirstVisibleCardInOrder() {
        let order = ["vitD", "omega", "mag", "water", "protein"]
        XCTAssertEqual(TodayLayout.anchor(in: order, visible: ["water", "mag", "protein"]), "mag")
        XCTAssertEqual(TodayLayout.anchor(in: order, visible: ["protein"]), "protein")
    }

    func testNoAnchorAtTheTopOrWithNothingVisible() {
        let order = ["vitD", "omega", "mag"]
        XCTAssertNil(TodayLayout.anchor(in: order, visible: ["vitD", "omega"]), "the page is at the top")
        XCTAssertNil(TodayLayout.anchor(in: order, visible: []))
        XCTAssertNil(TodayLayout.anchor(in: [String](), visible: ["vitD"]))
    }
}
