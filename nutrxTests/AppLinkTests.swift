import XCTest
@testable import nutrx

final class AppLinkTests: XCTestCase {
    func testLinks() throws {
        XCTAssertEqual(AppLink(try XCTUnwrap(URL(string: "nutrx://today"))), .today)
        XCTAssertEqual(AppLink(try XCTUnwrap(URL(string: "nutrx://nutrients"))), .nutrients)
        XCTAssertEqual(AppLink(try XCTUnwrap(URL(string: "nutrx://pro"))), .pro)
        let id = UUID()
        XCTAssertEqual(AppLink(try XCTUnwrap(URL(string: "nutrx://nutrients/\(id.uuidString)"))), .nutrient(id))
    }

    func testEachLinkReadsBackFromItsURL() {
        for link in [AppLink.today, .nutrients, .nutrient(UUID()), .pro] {
            XCTAssertEqual(AppLink(link.url), link)
        }
    }

    func testOtherURLsAreNotLinks() throws {
        for string in ["https://nutrx.nutrx-labs.com/pro", "nutrx://settings", "nutrx://nutrients/not-a-uuid",
                       "nutrx://today/extra", "nutrx://pro/yearly", "other://today", "nutrx:"] {
            XCTAssertNil(AppLink(try XCTUnwrap(URL(string: string))), string)
        }
    }

    func testTheRouterFollowsLinks() {
        let router = NotificationRouter()
        router.open(.pro)
        XCTAssertTrue(router.showsPaywall)
        let id = UUID()
        router.open(.nutrient(id))
        XCTAssertEqual(router.nutrientID, id)
        router.open(.nutrients)
        XCTAssertEqual(router.linkedTab, .nutrients)
        router.open(.today)
        XCTAssertEqual(router.linkedTab, .today)
    }
}
