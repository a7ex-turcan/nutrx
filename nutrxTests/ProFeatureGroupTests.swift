import XCTest
@testable import nutrx

/// The paywall's grouped rows.
final class ProFeatureGroupTests: XCTestCase {
    /// A new Pro feature has to join a group, or the paywall would never mention it.
    func testEveryFeatureIsInExactlyOneGroup() {
        let grouped = ProFeatureGroup.allCases.flatMap(\.features)
        XCTAssertEqual(grouped.count, Set(grouped).count, "no feature in two groups")
        XCTAssertEqual(Set(grouped), Set(ProFeature.allCases))
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
}
