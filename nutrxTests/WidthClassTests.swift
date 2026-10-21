import XCTest
@testable import nutrx

/// Large-screen width classes and the readable column (#151, docs/design/large-screens/LAYOUT.md).
final class WidthClassTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(WidthClass(width: 402), .compact, "iPhone")
        XCTAssertEqual(WidthClass(width: 466), .compact, "folded Duo")
        XCTAssertEqual(WidthClass(width: 703.5), .compact)
        XCTAssertEqual(WidthClass(width: 704), .regular, "two card columns fit from here")
        XCTAssertEqual(WidthClass(width: 951), .regular, "unfolded Duo")
        XCTAssertEqual(WidthClass(width: 999), .regular)
        XCTAssertEqual(WidthClass(width: 1000), .wide)
        XCTAssertEqual(WidthClass(width: 1376), .wide, "13-inch iPad, landscape")
    }

    func testMargins() {
        XCTAssertEqual(WidthClass.regular.minimumMargin, 24)
        XCTAssertEqual(WidthClass.wide.minimumMargin, 40)
    }

    func testTheColumnLeavesCompactWidthsAlone() {
        XCTAssertEqual(ReadableColumn.extraInset(width: 402, ownMargin: 16), 0)
        XCTAssertEqual(ReadableColumn.extraInset(width: 703, ownMargin: 16), 0)
    }

    func testTheColumnIsAtMost640Wide() {
        // 13-inch iPad landscape: (1376 − 640) / 2 = 368 each side, 16 of it the content's own margin.
        XCTAssertEqual(ReadableColumn.extraInset(width: 1376, ownMargin: 16), 352)
        XCTAssertEqual(1376 - 2 * (352 + 16), 640)
        // 11-inch iPad portrait (834): 97 each side.
        XCTAssertEqual(ReadableColumn.extraInset(width: 834, ownMargin: 20), 77)
    }

    func testTheColumnKeepsTheMinimumMarginWhenNarrow() {
        // 704: (704 − 640) / 2 = 32 ≥ 24, so the column is 640.
        XCTAssertEqual(ReadableColumn.extraInset(width: 704, ownMargin: 16), 16)
        // Content that already has more margin than needed gets nothing extra.
        XCTAssertEqual(ReadableColumn.extraInset(width: 704, ownMargin: 40), 0)
    }
}
