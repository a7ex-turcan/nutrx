import XCTest
@testable import nutrx

final class WhatsNewTests: XCTestCase {
    private let releases = [WhatsNew(version: "2.3", items: [
        WhatsNew.Item(title: "Everywhere", subtitle: "a", symbolName: "star", tint: .blue),
        WhatsNew.Item(title: "iPad", subtitle: "b", symbolName: "ipad", tint: .green, iPadOnly: true),
    ])]

    func testShowsOnceForTheReleaseAndItsPatches() {
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, isPad: true, releases: releases)?.version,
                       "2.3")
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3.1", hiddenVersion: "2.2", isPad: true,
                                     releases: releases)?.version, "2.3")
        XCTAssertNil(WhatsNew.card(appVersion: "2.3.1", hiddenVersion: "2.3", isPad: true, releases: releases),
                     "hidden for 2.3, so not again for 2.3.1")
    }

    func testNothingForAReleaseWithoutACard() {
        XCTAssertNil(WhatsNew.card(appVersion: "2.2.1", hiddenVersion: nil, isPad: true, releases: releases))
        XCTAssertNil(WhatsNew.card(appVersion: "2.4", hiddenVersion: "2.3", isPad: true, releases: releases))
    }

    func testIPadOnlyItems() {
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, isPad: true, releases: releases)?
            .items.map(\.title), ["Everywhere", "iPad"])
        XCTAssertEqual(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, isPad: false, releases: releases)?
            .items.map(\.title), ["Everywhere"])
        let iPadOnly = [WhatsNew(version: "2.3", items: [
            WhatsNew.Item(title: "iPad", subtitle: "b", symbolName: "ipad", tint: .green, iPadOnly: true),
        ])]
        XCTAssertNil(WhatsNew.card(appVersion: "2.3", hiddenVersion: nil, isPad: false, releases: iPadOnly),
                     "nothing left for an iPhone")
    }

    /// Installed fresh on 2.3: onboarding marks 2.3 seen, so no card on day two or any day of 2.3 — but 2.4's.
    func testAFreshInstallSeesNothingUntilTheNextRelease() throws {
        let name = "WhatsNewTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        WhatsNew.markSeenAtOnboarding(appVersion: "2.3.0", defaults: defaults)
        let hidden = defaults.string(forKey: WhatsNew.hiddenVersionKey)
        XCTAssertEqual(hidden, "2.3")
        XCTAssertNil(WhatsNew.card(appVersion: "2.3", hiddenVersion: hidden, isPad: true, releases: releases))
        let next = releases + [WhatsNew(version: "2.4", items: [
            WhatsNew.Item(title: "New", subtitle: "c", symbolName: "star", tint: .blue),
        ])]
        XCTAssertEqual(WhatsNew.card(appVersion: "2.4", hiddenVersion: hidden, isPad: false, releases: next)?.version,
                       "2.4")
    }

    func testMajorMinor() {
        XCTAssertEqual(WhatsNew.majorMinor("2.3.1"), "2.3")
        XCTAssertEqual(WhatsNew.majorMinor("2.3"), "2.3")
        XCTAssertEqual(WhatsNew.majorMinor("3"), "3")
    }

    func testTheShippedReleasesHaveContent() {
        for release in WhatsNew.releases {
            XCTAssertFalse(release.items.isEmpty, release.version)
            XCTAssertFalse(release.items.filter { !$0.iPadOnly }.isEmpty, "\(release.version) has something for iPhone")
            XCTAssertEqual(WhatsNew.majorMinor(release.version), release.version, "keyed by major.minor")
        }
    }
}
