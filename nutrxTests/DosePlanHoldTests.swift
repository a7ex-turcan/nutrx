import SwiftData
import XCTest
@testable import nutrx

/// Dose plans without Pro (#135, docs/pro/DOSE-PLANS.md §6): the hold from the day a device finds out, the Pro marker
/// that keeps two devices from holding and resuming back and forth, and the resume.
@MainActor
final class DosePlanHoldTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    /// 200 mg from 10 Nov for 10 days (10–19), then 400 mg for 11 (20–30), created on 10 Nov.
    private func nutrient(end: NutrientDosePlan.End = .keep, seenWithPro: String = "") -> Nutrient {
        let nutrient = Nutrient(name: "Magnesium", unit: "mg", step: 100, dailyTarget: 100, sortOrder: 0)
        let plan = NutrientDosePlan().creating(
            steps: [.init(goal: NutrientGoal(target: 200), days: 10), .init(goal: NutrientGoal(target: 400), days: 11)],
            end: end, start: day(11, 10), base: NutrientGoal(target: 100), today: day(11, 10), calendar: calendar)
        nutrient.dosePlanRaw = plan.encode(calendar: calendar)
        nutrient.dosePlanSeenWithPro = seenWithPro
        if let stopDay = plan.stopDay(calendar: calendar) { nutrient.endDate = stopDay }
        context.insert(nutrient)
        return nutrient
    }

    private func plan(of nutrient: Nutrient) -> NutrientDosePlan {
        nutrient.dosePlan(calendar: calendar)
    }

    func testWithoutProAMovingPlanHoldsFromToday() {
        let magnesium = nutrient()
        XCTAssertTrue(DosePlanHold.sync(isPro: false, context: context, now: day(11, 12), calendar: calendar))
        XCTAssertEqual(plan(of: magnesium).plan?.heldFrom, calendar.startOfDay(for: day(11, 12)))
        XCTAssertEqual(plan(of: magnesium).goal(on: day(11, 25), calendar: calendar)?.target, 200, "later steps wait")
        XCTAssertEqual(plan(of: magnesium).goal(on: day(11, 11), calendar: calendar)?.target, 200)
        XCTAssertFalse(DosePlanHold.sync(isPro: false, context: context, now: day(11, 13), calendar: calendar),
                       "held once")
    }

    func testAMarkerFromYesterdayKeepsItRunning() {
        let magnesium = nutrient(seenWithPro: "20261111")
        XCTAssertFalse(DosePlanHold.sync(isPro: false, context: context, now: day(11, 12), calendar: calendar),
                       "another device knew Pro yesterday")
        XCTAssertNil(plan(of: magnesium).plan?.heldFrom)
        XCTAssertTrue(DosePlanHold.sync(isPro: false, context: context, now: day(11, 13), calendar: calendar),
                      "more than a day old")
    }

    func testWithProTheMarkerIsTodayAndAHeldPlanResumes() {
        let magnesium = nutrient()
        DosePlanHold.sync(isPro: false, context: context, now: day(11, 12), calendar: calendar)
        XCTAssertTrue(DosePlanHold.sync(isPro: true, context: context, now: day(11, 15), calendar: calendar))
        XCTAssertNil(plan(of: magnesium).plan?.heldFrom)
        XCTAssertEqual(magnesium.dosePlanSeenWithPro, "20261115")
        // Held 12–14: step 1 runs 3 days longer, to 22 Nov.
        XCTAssertEqual(plan(of: magnesium).goal(on: day(11, 22), calendar: calendar)?.target, 200)
        XCTAssertEqual(plan(of: magnesium).goal(on: day(11, 23), calendar: calendar)?.target, 400)
        XCTAssertFalse(DosePlanHold.sync(isPro: true, context: context, now: day(11, 15, hour: 20), calendar: calendar),
                       "the marker at most once a day")
    }

    func testAStoppingPlansEndIsLiftedWhileHeldAndSetAgainOnResume() {
        let magnesium = nutrient(end: .stop)
        XCTAssertEqual(magnesium.endDate, calendar.startOfDay(for: day(11, 30)))
        DosePlanHold.sync(isPro: false, context: context, now: day(11, 12), calendar: calendar)
        XCTAssertNil(magnesium.endDate, "a held plan doesn't stop")
        DosePlanHold.sync(isPro: true, context: context, now: day(11, 15), calendar: calendar)
        XCTAssertEqual(magnesium.endDate, calendar.startOfDay(for: day(12, 3)), "3 days later")
    }

    func testAPlanThatsDoneNeverHolds() {
        let kept = nutrient()
        XCTAssertFalse(DosePlanHold.sync(isPro: false, context: context, now: day(12, 5), calendar: calendar))
        XCTAssertNil(plan(of: kept).plan?.heldFrom)
        XCTAssertFalse(DosePlanHold.sync(isPro: true, context: context, now: day(12, 5), calendar: calendar),
                       "no marker for a plan that can't hold")
        XCTAssertEqual(kept.dosePlanSeenWithPro, "")
    }
}
