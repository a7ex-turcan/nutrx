#if DEBUG
import XCTest
@testable import nutrx

final class ScreenshotRouteTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testTabs() {
        XCTAssertEqual(ScreenshotRoute.parse("today"), .today)
        XCTAssertEqual(ScreenshotRoute.parse("Nutrients"), .nutrients)
        XCTAssertEqual(ScreenshotRoute.parse("stacks"), .stacks)
        XCTAssertEqual(ScreenshotRoute.parse("history"), .history)
        XCTAssertEqual(ScreenshotRoute.parse("paywall"), .paywall)
    }

    func testNutrientByName() {
        XCTAssertEqual(ScreenshotRoute.parse("nutrients/Vitamin D"), .nutrient(name: "Vitamin D"))
        // Everything after the first slash is the name.
        XCTAssertEqual(ScreenshotRoute.parse("nutrients/Omega-3/6"), .nutrient(name: "Omega-3/6"))
    }

    func testHistoryDay() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20)))
        XCTAssertEqual(ScreenshotRoute.parse("history/2026-10-20", calendar: calendar), .historyDay(day))
        XCTAssertNil(ScreenshotRoute.parse("history/2026-02-30", calendar: calendar), "no such day")
        XCTAssertNil(ScreenshotRoute.parse("history/yesterday", calendar: calendar))
    }

    func testUnknown() {
        XCTAssertNil(ScreenshotRoute.parse(""))
        XCTAssertNil(ScreenshotRoute.parse("settings"))
        XCTAssertNil(ScreenshotRoute.parse("today/extra"))
        XCTAssertNil(ScreenshotRoute.parse("paywall/yearly"))
    }
}
#endif
