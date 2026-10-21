import XCTest
@testable import nutrx

final class WhatsNewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let longAgo = Date(timeIntervalSince1970: 1_700_000_000)
    private let releases = [WhatsNew(version: "2.3", items: [
        WhatsNew.Item(title: "A", subtitle: "a", symbolName: "star", tint: .blue),
    ])]

    func testShowsOnceForTheReleaseAndItsPatches() {
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, startedUsing: longAgo, now: now,
                                     releases: releases)?.version, "2.3")
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3.1", hiddenVersion: "2.2", startedUsing: longAgo, now: now,
                                     releases: releases)?.version, "2.3")
        XCTAssertNil(WhatsNew.card(appVersion: "2.3.1", hiddenVersion: "2.3", startedUsing: longAgo, now: now,
                                   releases: releases), "hidden for 2.3, so not again for 2.3.1")
    }

    func testNothingForAReleaseWithoutACard() {
        XCTAssertNil(WhatsNew.card(appVersion: "2.2.1", hiddenVersion: nil, startedUsing: longAgo, now: now,
                                   releases: releases))
        XCTAssertNil(WhatsNew.card(appVersion: "2.4", hiddenVersion: "2.3", startedUsing: longAgo, now: now,
                                   releases: releases))
    }

    func testNeverOnAFreshInstall() {
        XCTAssertNil(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, startedUsing: now.addingTimeInterval(-3600),
                                   now: now, releases: releases))
        XCTAssertNotNil(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil,
                                      startedUsing: now.addingTimeInterval(-2 * 24 * 3600), now: now,
                                      releases: releases))
    }

    func testMajorMinor() {
        XCTAssertEqual(WhatsNew.majorMinor("2.3.1"), "2.3")
        XCTAssertEqual(WhatsNew.majorMinor("2.3"), "2.3")
        XCTAssertEqual(WhatsNew.majorMinor("3"), "3")
    }

    func testTheShippedReleasesHaveContent() {
        for release in WhatsNew.releases {
            XCTAssertFalse(release.items.isEmpty, release.version)
            XCTAssertEqual(WhatsNew.majorMinor(release.version), release.version, "keyed by major.minor")
        }
    }
}
