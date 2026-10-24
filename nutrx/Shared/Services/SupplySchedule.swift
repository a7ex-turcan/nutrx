import Foundation

/// Supply & refills (nutrx Pro, docs/pro/PLAN.md phase 4): how much of a bottle is left and how long it lasts, from
/// the intake log alone. Pure, so the maths is tested without a store (`SupplyScheduleTests`).
///
/// - remaining = servings × serving amount − what's been logged since the refill (decrements count back in,
///   never below zero, never above a full bottle);
/// - daily use = the last 14 days' total ÷ the days since the first log in them, once there are at least 3 —
///   not tied to the refill, so a refill doesn't throw the estimate away;
/// - days left = remaining ÷ daily use, rounded down.
enum SupplySchedule {
    /// One logged amount (an `IntakeRecord`'s date and signed amount).
    struct Log: Equatable {
        let date: Date
        let amount: Double
    }

    struct Setup: Equatable {
        let servings: Double
        let servingAmount: Double
        let refilledAt: Date
        let reminderDays: Int
    }

    enum Level: Equatable {
        /// Nothing left: "Out of supply · Refilled?".
        case out
        /// At or under the reminder threshold: "About 6 days left".
        case low
        /// More than the threshold left; Today shows nothing.
        case plenty
        /// Not enough logging yet to estimate (fewer than 3 days in the last 14); Today shows nothing.
        case noHistory
    }

    struct Status: Equatable {
        let setup: Setup
        /// Units left in the bottle.
        let remaining: Double
        /// Average daily use, or nil without enough history.
        let dailyUse: Double?
        /// Whole days left, or nil without enough history.
        let daysLeft: Int?
        let level: Level

        var totalAmount: Double { setup.servings * setup.servingAmount }
        /// Servings left, rounded down ("12 of 120 left").
        var servingsLeft: Int { Int((remaining / setup.servingAmount + 1e-9).rounded(.down)) }
        /// 0…1 of a full bottle, for the gauge.
        var fractionLeft: Double { totalAmount > 0 ? min(1, max(0, remaining / totalAmount)) : 0 }
        /// Where the reminder threshold sits on the gauge (0…1), when daily use is known.
        var thresholdFraction: Double? {
            guard let dailyUse, totalAmount > 0 else { return nil }
            return min(1, Double(setup.reminderDays) * dailyUse / totalAmount)
        }
    }

    static let historyWindowDays = 14
    static let minimumHistoryDays = 3

    /// The status for a nutrient's supply setup and its logs (any range; only what matters is used).
    static func status(setup: Setup, logs: [Log], now: Date = .now, calendar: Calendar = .current) -> Status {
        let total = setup.servings * setup.servingAmount
        let usedSinceRefill = logs.filter { $0.date >= setup.refilledAt && $0.date <= now }.reduce(0) { $0 + $1.amount }
        let remaining = min(total, max(0, total - max(0, usedSinceRefill)))
        let dailyUse = averageDailyUse(logs: logs, now: now, calendar: calendar)
        let daysLeft = dailyUse.map { Int((remaining / $0 + 1e-9).rounded(.down)) }

        let level: Level
        // Out once less than a fifth of a serving is left: what's left in the bottle isn't a dose.
        if remaining < setup.servingAmount * 0.2 {
            level = .out
        } else if let daysLeft {
            level = daysLeft <= setup.reminderDays ? .low : .plenty
        } else {
            level = .noHistory
        }
        return Status(setup: setup, remaining: remaining, dailyUse: dailyUse, daysLeft: daysLeft, level: level)
    }

    /// Average use per day over the last 14 days, counted from the first day with a log in them; nil with fewer
    /// than 3 such days or no positive use. Today counts only once it has a log, so the morning before the first
    /// dose doesn't read as a day of no use.
    static func averageDailyUse(logs: [Log], now: Date = .now, calendar: Calendar = .current) -> Double? {
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(historyWindowDays - 1), to: today) else {
            return nil
        }
        let inWindow = logs.filter { $0.date >= windowStart && $0.date <= now }
        guard let first = inWindow.map(\.date).min() else { return nil }
        let firstDay = calendar.startOfDay(for: first)
        let loggedToday = inWindow.contains { $0.date >= today }
        let days = (calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0) + (loggedToday ? 1 : 0)
        guard days >= minimumHistoryDays else { return nil }
        let total = inWindow.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return nil }
        return total / Double(days)
    }

    /// The supply that runs out soonest, for the medium widget's "Running low" line: anything out first, then the
    /// fewest days left among low ones; nil when nothing is low or out.
    static func soonest<ID>(_ items: [(id: ID, status: Status)]) -> (id: ID, status: Status)? {
        let candidates = items.filter { $0.status.level == .out || $0.status.level == .low }
        return candidates.min { lhs, rhs in
            let l = lhs.status.level == .out ? -1 : (lhs.status.daysLeft ?? 0)
            let r = rhs.status.level == .out ? -1 : (rhs.status.daysLeft ?? 0)
            return l < r
        }
    }

    /// How long a full bottle lasts at a daily amount (the Supply sheet's "about 60 days").
    static func daysInBottle(servings: Double, servingAmount: Double, dailyAmount: Double) -> Int? {
        guard dailyAmount > 0 else { return nil }
        return Int((servings * servingAmount / dailyAmount + 1e-9).rounded(.down))
    }
}

extension Nutrient {
    /// The serving size: `servingAmount`, or one step.
    var effectiveServingAmount: Double {
        servingAmount.flatMap { $0 > 0 ? $0 : nil } ?? step
    }

    /// The supply setup, if supply is set.
    var supplySetup: SupplySchedule.Setup? {
        guard let servings = supplyServings, servings > 0, let refilledAt = supplyRefilledAt else { return nil }
        return SupplySchedule.Setup(servings: servings, servingAmount: effectiveServingAmount, refilledAt: refilledAt,
                                    reminderDays: refillReminderDays)
    }

    /// The supply status from this nutrient's own records, if supply is set.
    func supplyStatus(now: Date = .now, calendar: Calendar = .current) -> SupplySchedule.Status? {
        guard let setup = supplySetup else { return nil }
        // Only what the status reads: since the refill and over the usage window, never the whole history (the
        // supply widget asks for every bottle on each reload, #138).
        let windowStart = calendar.date(byAdding: .day, value: -(SupplySchedule.historyWindowDays - 1),
                                        to: calendar.startOfDay(for: now)) ?? setup.refilledAt
        let logs = records(from: min(setup.refilledAt, windowStart), to: .distantFuture)
            .map { SupplySchedule.Log(date: $0.date, amount: $0.amount) }
        return SupplySchedule.status(setup: setup, logs: logs, now: now, calendar: calendar)
    }

    /// "Refilled": the count starts again from a full bottle.
    func refillSupply(now: Date = .now) {
        supplyRefilledAt = now
    }
}
