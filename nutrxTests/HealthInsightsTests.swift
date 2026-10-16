import XCTest
@testable import nutrx

/// Where Apple Health insights stand across nutrients (#102), and the words for each place that shows it.
final class HealthInsightsTests: XCTestCase {
    private let a = UUID(), b = UUID(), c = UUID()

    private func finding() -> HealthTrends.Finding {
        HealthTrends.Finding(kind: .workouts, first: .init(average: 10, days: 5), second: .init(average: 5, days: 9),
                             threshold: nil)
    }

    func testAFindingAnywhereWins() {
        let status = HealthInsights.status([
            .init(id: a, name: "Vitamin D", state: .notEnoughData(pairedDays: 12)),
            .init(id: b, name: "Caffeine", state: .findings([finding()])),
        ])
        XCTAssertEqual(status, .ready(nutrientID: b, nutrientName: "Caffeine"))
    }

    func testGatheringPicksTheClosestNutrient() {
        let status = HealthInsights.status([
            .init(id: a, name: "Vitamin D", state: .notEnoughData(pairedDays: 6)),
            .init(id: b, name: "Omega-3", state: .notEnoughData(pairedDays: 9)),
            .init(id: c, name: "Water", state: .notEnoughData(pairedDays: 9)),
        ])
        XCTAssertEqual(status, .gathering(nutrientID: b, nutrientName: "Omega-3", pairedDays: 9), "the first on a tie")
    }

    func testNoPatternAndNoHealthData() {
        XCTAssertEqual(HealthInsights.status([.init(id: a, name: "Vitamin D", state: .noPattern(checkedDays: 20)),
                                             .init(id: b, name: "Omega-3", state: .noHealthData)]), .noPattern)
        XCTAssertEqual(HealthInsights.status([.init(id: a, name: "Vitamin D", state: .noHealthData)]), .noHealthData)
        XCTAssertNil(HealthInsights.status([]))
    }

    func testWords() {
        let gathering = HealthInsights.Status.gathering(nutrientID: a, nutrientName: "Vitamin D", pairedDays: 9)
        let ready = HealthInsights.Status.ready(nutrientID: a, nutrientName: "Vitamin D")
        XCTAssertEqual(HealthText.todayTitle(gathering), "Insights from Apple Health are on the way")
        XCTAssertEqual(HealthText.todayBody(gathering), "Keep logging: Vitamin D has 9 of 14 days with your logs and Health data.")
        XCTAssertEqual(HealthText.todayTitle(ready), "Your first Apple Health insight is ready")
        XCTAssertNil(HealthText.todayTitle(.noPattern))
        XCTAssertEqual(HealthText.settingsStatus(gathering), "So far: 9 of 14 days for Vitamin D. Insights start at 14.")
        XCTAssertEqual(HealthText.recapLine(gathering), "Apple Health insights start after about two weeks of logging.")
        XCTAssertNil(HealthText.recapLine(.noHealthData))
        // Descriptive only, like the rest of the Health words.
        for text in [HealthText.connectedBody, HealthText.whereLine, HealthText.todayBody(ready) ?? ""] {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("should"), text)
        }
    }
}
