import XCTest
import SwiftData
@testable import nutrx

/// What the one-nutrient widget shows (#138, docs/pro/WIDGETS.md §3).
@MainActor
final class NutrientWidgetContentTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    private let en = Locale(identifier: "en_GB")

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func day(_ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func vitaminD() -> Nutrient {
        let nutrient = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        nutrient.createdAt = day(10, 1)
        context.insert(nutrient)
        return nutrient
    }

    private func make(_ nutrient: Nutrient?, chosen: Bool = true, total: Double = 0, isPro: Bool = true,
                      now: Date? = nil) -> NutrientWidgetContent {
        NutrientWidgetContent.make(chosen: chosen, nutrient: nutrient, todayTotal: total, isPro: isPro,
                                   now: now ?? day(10, 24), calendar: calendar, locale: en)
    }

    private func status(_ content: NutrientWidgetContent) -> NutrientWidgetContent.Status? {
        if case .nutrient(let shown) = content { shown.status } else { nil }
    }

    func testDueShowsTodaysProgress() throws {
        let nutrient = vitaminD()
        let content = make(nutrient, total: 2000)
        guard case .nutrient(let shown) = content else { return XCTFail("\(content)") }
        XCTAssertEqual(shown.id, nutrient.id)
        XCTAssertEqual(shown.name, "Vitamin D")
        XCTAssertEqual(shown.status, .due(GoalProgress(nutrient: nutrient, current: 2000)))
    }

    func testANegativeTotalReadsAsZero() {
        XCTAssertEqual(status(make(vitaminD(), total: -1000)),
                       .due(GoalProgress(current: 0, goalType: .minimum, target: 4000, upperBound: nil, unit: "IU")))
    }

    func testFreeComesFirst() {
        XCTAssertEqual(make(vitaminD(), isPro: false), .free)
        XCTAssertEqual(make(nil, chosen: false, isPro: false), .free)
    }

    func testNothingChosenOrGoneAsksForOne() {
        XCTAssertEqual(make(nil, chosen: false), .choose)
        XCTAssertEqual(make(nil, chosen: true), .choose, "the pick is gone from the store")
    }

    func testRemovedAndEndedSaySo() {
        let removed = vitaminD()
        removed.isRemoved = true
        XCTAssertEqual(status(make(removed)), .removed)
        XCTAssertEqual(status(make(removed))?.captions, ["Removed in nutrx"])

        let ended = vitaminD()
        ended.endDate = calendar.startOfDay(for: day(10, 22))
        XCTAssertEqual(status(make(ended)), .courseEnded)
        XCTAssertEqual(status(make(ended))?.captions, ["Course ended"])
        ended.endDate = calendar.startOfDay(for: day(10, 24))
        XCTAssertEqual(status(make(ended, total: 1000)), .due(GoalProgress(nutrient: ended, current: 1000)),
                       "its last day still shows")
    }

    func testAnOffDayShowsTheNextOne() {
        // Mon, Wed, Fri from Monday 19 October; Saturday 24th is off, Monday 26th is next.
        let nutrient = vitaminD()
        nutrient.scheduleRaw = "20261019=days:2,4,6"
        XCTAssertEqual(status(make(nutrient)), .notToday(next: "Next: Monday"))
        XCTAssertEqual(status(make(nutrient))?.captions, ["Not today", "Next: Monday"])
        XCTAssertEqual(status(make(nutrient, now: day(10, 23))), .due(GoalProgress(nutrient: nutrient, current: 0)))
    }
}
