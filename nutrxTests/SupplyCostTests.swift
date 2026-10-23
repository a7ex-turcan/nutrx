import SwiftData
import XCTest
@testable import nutrx

/// Supply costs (nutrx Pro, #134, docs/pro/SUPPLY-COSTS.md).
final class SupplyCostTests: XCTestCase {
    private let enUS = Locale(identifier: "en_US")

    func testDoseShareFollowsTheSchedule() {
        XCTAssertEqual(SupplyCost.doseShare(.everyDay), 1)
        XCTAssertEqual(SupplyCost.doseShare(.weekdays([2, 4, 6])), 3.0 / 7)
        XCTAssertEqual(SupplyCost.doseShare(.cycle(on: 5, off: 2, start: .now)), 5.0 / 7)
        XCTAssertEqual(SupplyCost.doseShare(.weekly(times: 3)), 3.0 / 7)
    }

    func testDailyUseIsTheEstimateOrTheGoalOnDoseDays() {
        XCTAssertEqual(SupplyCost.dailyUse(estimate: 1500, goalType: .minimum, target: 1000, doseShare: 1), 1500)
        XCTAssertEqual(SupplyCost.dailyUse(estimate: nil, goalType: .minimum, target: 1000, doseShare: 0.5), 500)
        XCTAssertEqual(SupplyCost.dailyUse(estimate: nil, goalType: .range, target: 120, doseShare: 1), 120,
                       "a range's lower bound")
        XCTAssertNil(SupplyCost.dailyUse(estimate: nil, goalType: .maximum, target: 400, doseShare: 1),
                     "the limit isn't what's taken")
        XCTAssertEqual(SupplyCost.dailyUse(estimate: 300, goalType: .maximum, target: 400, doseShare: 1), 300)
    }

    func testMonthlyCost() throws {
        // A $12 bottle of 120 × 1,000 IU at 2,000 IU a day lasts 60 days: about $6 a month.
        let monthly = try XCTUnwrap(SupplyCost.monthly(price: 12, bottleAmount: 120_000, dailyUse: 2000))
        XCTAssertEqual(monthly, 12.0 / 60 * 365 / 12, accuracy: 1e-9)
        XCTAssertNil(SupplyCost.monthly(price: nil, bottleAmount: 120_000, dailyUse: 2000))
        XCTAssertNil(SupplyCost.monthly(price: 12, bottleAmount: 120_000, dailyUse: nil))
        XCTAssertNil(SupplyCost.monthly(price: 0, bottleAmount: 120_000, dailyUse: 2000))
    }

    func testTotals() {
        XCTAssertEqual(SupplyCost.total([4, 6], unpriced: 2), SupplyCost.Total(monthly: 10, priced: 2, unpriced: 2))
        XCTAssertNil(SupplyCost.total([], unpriced: 2), "no costs, no line")
    }

    func testWording() {
        XCTAssertEqual(SupplyText.money(38.4, locale: enUS), "$38")
        XCTAssertEqual(SupplyText.money(3.6, locale: enUS), "$3.60")
        XCTAssertEqual(SupplyText.money(9.996, locale: enUS), "$10", "rounds to 10, so it's shown whole")
        XCTAssertEqual(SupplyText.monthlyCost(6.08, locale: enUS), "About $6.08 a month")
        XCTAssertEqual(SupplyText.totalCost(.init(monthly: 38.2, priced: 5, unpriced: 0), locale: enUS),
                       "About $38 a month for 5 nutrients")
        XCTAssertEqual(SupplyText.totalCost(.init(monthly: 4, priced: 1, unpriced: 2), locale: enUS),
                       "About $4.00 a month for 1 nutrient · 2 without a price")
        XCTAssertEqual(SupplyText.stackCost(.init(monthly: 12.4, priced: 2, unpriced: 0), locale: enUS),
                       "This stack costs about $12 a month")
        XCTAssertEqual(SupplyText.stackCost(.init(monthly: 12.4, priced: 2, unpriced: 1), locale: enUS),
                       "This stack costs about $12 a month · 1 without a price")
        // The currency's own minor units: none for the yen; a no-break space before the euro sign.
        XCTAssertEqual(SupplyText.money(8.4, locale: Locale(identifier: "ja_JP")), "¥8")
        XCTAssertEqual(SupplyText.money(480, locale: Locale(identifier: "ja_JP")), "¥480")
        XCTAssertEqual(SupplyText.money(38.4, locale: Locale(identifier: "de_DE")).replacingOccurrences(of: "\u{00A0}", with: " "),
                       "38 €")
        XCTAssertEqual(SupplyText.money(3.6, locale: Locale(identifier: "de_DE")).replacingOccurrences(of: "\u{00A0}", with: " "),
                       "3,60 €")
    }

    /// From a nutrient: its own logs' daily use, or its goal on dose days without history; only running nutrients
    /// with supply count toward a total.
    func testNutrientsCostAndTotal() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date.now
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 2000, sortOrder: 0)
        vitaminD.supplyServings = 120
        vitaminD.supplyRefilledAt = calendar.date(byAdding: .day, value: -1, to: now)
        vitaminD.supplyPrice = 12
        let omega = Nutrient(name: "Omega-3", unit: "mg", step: 1000, dailyTarget: 1000, sortOrder: 1)
        omega.supplyServings = 60
        omega.supplyRefilledAt = vitaminD.supplyRefilledAt
        let ended = Nutrient(name: "Iron", unit: "mg", step: 10, dailyTarget: 10, sortOrder: 2)
        ended.supplyServings = 30
        ended.supplyRefilledAt = vitaminD.supplyRefilledAt
        ended.supplyPrice = 9
        ended.endDate = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: now))
        let noSupply = Nutrient(name: "Water", unit: "L", step: 0.5, dailyTarget: 2.5, sortOrder: 3)
        // Priced, but an "at most" goal with no history: no cost yet, and not "without a price" either.
        let caffeine = Nutrient(name: "Caffeine", unit: "mg", step: 100, dailyTarget: 400, sortOrder: 4)
        caffeine.goalTypeRaw = GoalType.maximum.rawValue
        caffeine.supplyServings = 50
        caffeine.supplyRefilledAt = vitaminD.supplyRefilledAt
        caffeine.supplyPrice = 8
        [vitaminD, omega, ended, noSupply, caffeine].forEach(context.insert)
        try context.save()

        // No history: Vitamin D at its goal, 2,000 IU a day of a 120,000 IU bottle.
        let cost = try XCTUnwrap(vitaminD.monthlySupplyCost(now: now))
        XCTAssertEqual(cost, 12.0 / 60 * 365 / 12, accuracy: 1e-6)
        XCTAssertNil(omega.monthlySupplyCost(now: now), "no price")

        XCTAssertNil(caffeine.monthlySupplyCost(now: now))
        let total = try XCTUnwrap(SupplyCost.total(of: [vitaminD, omega, ended, noSupply, caffeine], now: now))
        XCTAssertEqual(total.priced, 1, "Iron's course has ended; Water has no supply; Caffeine has no cost yet")
        XCTAssertEqual(total.unpriced, 1, "Omega-3 only: Caffeine has a price")
        XCTAssertEqual(total.monthly, cost, accuracy: 1e-9)
    }
}
