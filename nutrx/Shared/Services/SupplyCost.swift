import Foundation

/// What a nutrient's supply costs a month (nutrx Pro, #134, docs/pro/SUPPLY-COSTS.md): its price per bottle, spread
/// over how fast the bottle goes. Pure, tested in `SupplyCostTests`.
enum SupplyCost {
    static let daysPerMonth = 365.0 / 12

    /// The share of days a schedule makes dose days: weekdays n / 7, a cycle on / (on + off), times a week n / 7,
    /// every day 1.
    static func doseShare(_ kind: NutrientSchedule.Kind) -> Double {
        switch kind {
        case .everyDay: 1
        case .weekdays(let days): Double(days.count) / 7
        case .cycle(let on, let off, _): on + off > 0 ? Double(on) / Double(on + off) : 1
        case .weekly(let times): Double(times) / 7
        }
    }

    /// The daily amount to price: supply's own estimate, or without one the goal on dose days (the Supply sheet's
    /// "at your goal of …"). Nil for an "at most" goal with no history: the limit isn't what's taken.
    static func dailyUse(estimate: Double?, goalType: GoalType, target: Double, doseShare: Double) -> Double? {
        if let estimate, estimate > 0 { return estimate }
        guard goalType != .maximum, target > 0, doseShare > 0 else { return nil }
        return target * doseShare
    }

    /// A month of `dailyUse` out of bottles of `bottleAmount` costing `price`; nil without a price or a use.
    static func monthly(price: Double?, bottleAmount: Double, dailyUse: Double?) -> Double? {
        guard let price, price > 0, bottleAmount > 0, let dailyUse, dailyUse > 0 else { return nil }
        return price / bottleAmount * dailyUse * daysPerMonth
    }

    /// Several nutrients' monthly costs added up, and how many with supply set have no price yet.
    struct Total: Equatable {
        let monthly: Double
        let priced: Int
        let unpriced: Int
    }

    /// The total of some monthly costs, with how many nutrients have supply but no price; nil without a cost.
    static func total(_ costs: [Double], unpriced: Int) -> Total? {
        guard !costs.isEmpty else { return nil }
        return Total(monthly: costs.reduce(0, +), priced: costs.count, unpriced: unpriced)
    }
}

extension Nutrient {
    /// What its supply costs a month at its usual use (or its goal on dose days), if it has supply and a price.
    func monthlySupplyCost(now: Date = .now, calendar: Calendar = .current) -> Double? {
        guard supplyPrice != nil, let status = supplyStatus(now: now, calendar: calendar) else { return nil }
        let share = SupplyCost.doseShare(schedule(calendar: calendar).kind(on: now, calendar: calendar))
        let use = SupplyCost.dailyUse(estimate: status.dailyUse, goalType: goalType, target: dailyTarget,
                                      doseShare: share)
        return SupplyCost.monthly(price: supplyPrice, bottleAmount: status.totalAmount, dailyUse: use)
    }
}

extension SupplyCost {
    /// The monthly total of the nutrients that have supply set and are running (not removed, course not ended); nil
    /// when none of them has a cost. Those with supply but no price count as `unpriced`; a priced one with no cost yet
    /// (an "at most" goal before there's history) isn't counted either way.
    static func total(of nutrients: [Nutrient], now: Date = .now, calendar: Calendar = .current) -> Total? {
        let withSupply = nutrients.filter { $0.isRunning(on: now, calendar: calendar) && $0.supplySetup != nil }
        return total(withSupply.compactMap { $0.monthlySupplyCost(now: now, calendar: calendar) },
                     unpriced: withSupply.filter { $0.supplyPrice == nil }.count)
    }
}
