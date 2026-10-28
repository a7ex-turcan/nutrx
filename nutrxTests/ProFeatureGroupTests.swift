import XCTest
@testable import nutrx

/// The paywall's grouped rows.
final class ProFeatureGroupTests: XCTestCase {
    /// A Pro feature joins a group once it ships, or the paywall would never mention it; before that it stays out
    /// (the next test), so a case can be added ahead of shipping.
    func testEveryShippedFeatureIsInExactlyOneGroup() {
        let grouped = ProFeatureGroup.allCases.flatMap(\.features)
        XCTAssertEqual(grouped.count, Set(grouped).count, "no feature in two groups")
        XCTAssertEqual(Set(grouped), Set(ProFeature.allCases.filter(\.isShipped)))
    }

    /// A row's words name every feature in it, so a group may only hold shipped ones; `listed` shows a group once any
    /// of its features is listed, which is only safe while this holds.
    func testGroupsOnlyHoldShippedFeatures() {
        for group in ProFeatureGroup.allCases {
            XCTAssertTrue(group.features.allSatisfy(\.isShipped), "\(group) names a feature that isn't shipped")
        }
    }

    func testFourRowsInOrder() {
        XCTAssertEqual(ProFeatureGroup.groups(listing: ProFeature.allCases), [.supply, .plans, .insights, .widgets])
        XCTAssertEqual(ProFeatureGroup.groups(listing: ProFeature.allCases).map(\.title),
                       ["Supply & label scan", "Courses & schedules", "Recaps, trends & reports",
                        "Widgets and controls"])
    }

    /// A group shows while any of its features is listed (shipped).
    func testOnlyGroupsWithAListedFeatureShow() {
        XCTAssertEqual(ProFeatureGroup.groups(listing: [.supply]), [.supply])
        XCTAssertEqual(ProFeatureGroup.groups(listing: [.report, .courses]), [.plans, .insights])
        XCTAssertEqual(ProFeatureGroup.groups(listing: []), [])
    }

    /// Without Apple Intelligence a group carries its features' note: label scanning in Supply, recaps in Insights.
    func testAppleIntelligenceNotesFollowTheirFeatures() {
        XCTAssertEqual(ProText.appleIntelligenceRowNote(ProFeatureGroup.supply, reading: .basic, device: "iPhone"),
                       ProText.appleIntelligenceRowNote(ProFeature.scan, reading: .basic, device: "iPhone"))
        XCTAssertEqual(ProText.appleIntelligenceRowNote(ProFeatureGroup.insights, reading: .basic, device: "iPhone"),
                       "Simpler wording on this iPhone")
        XCTAssertNil(ProText.appleIntelligenceRowNote(ProFeatureGroup.plans, reading: .basic, device: "iPhone"))
        XCTAssertNil(ProText.appleIntelligenceRowNote(ProFeatureGroup.insights, reading: .model, device: "iPhone"))
    }

    /// Only listed features add a note: with label scanning unlisted, Supply & label scan has none.
    func testAnUnlistedFeatureAddsNoNote() {
        XCTAssertNil(ProText.appleIntelligenceRowNote(ProFeatureGroup.supply, listed: [.supply], reading: .basic,
                                                      device: "iPhone"))
        XCTAssertNotNil(ProText.appleIntelligenceRowNote(ProFeatureGroup.supply, listed: [.supply, .scan],
                                                         reading: .basic, device: "iPhone"))
    }
}
