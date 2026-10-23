import Foundation

/// How a day reads on the History calendar (DESIGN.md §4.9).
enum DayCompletion: Equatable {
    /// Nothing was logged — no fill.
    case noEntries
    /// Something was logged but no goal was met — no fill.
    case noneMet
    /// Some goals met — green @ 25%.
    case someMet
    /// Every goal that counted was met — the same days `StreakService` counts as streak days.
    case allMet
    /// Something was logged on a rest day, when nothing was due (schedules, #132) — no fill, but it opens.
    case rest
}

/// What History needs to know about a nutrient, independent of SwiftData.
struct HistoryNutrient: Identifiable, Equatable {
    let id: UUID
    let goalType: GoalType
    let target: Double
    let upperBound: Double?
    let createdAt: Date
    let isRemoved: Bool
    /// The last day of a set course (#99); it doesn't count after it.
    var endDate: Date? = nil
    /// Days between a course's end and its restart; they don't count either.
    var courseGaps: [ClosedRange<Date>] = []
    /// Which days it's due (#132); off days don't count.
    var schedule = NutrientSchedule()
}

/// One past (or the current) day in History.
struct HistoryDay: Identifiable, Equatable {
    struct Goal: Identifiable, Equatable {
        let nutrientID: UUID
        /// The day's total, floored at 0.
        let total: Double
        let isMet: Bool

        var id: UUID { nutrientID }
    }

    /// Start of the day.
    let date: Date
    /// The nutrients that counted that day — not deleted, already created, not excluded — in display order.
    let goals: [Goal]
    /// Logged that day but not counted (a nutrient since removed, or excluded that day), in display order.
    let otherLogged: [Goal]
    let hasEntries: Bool
    /// Nothing was due that day: every nutrient off (schedules, #132) or past its course. Neither met nor missed, so
    /// it neither breaks nor extends a streak. A day whose nutrients were all excluded isn't one.
    var isRest = false

    var id: Date { date }
    var metCount: Int { goals.filter(\.isMet).count }

    var completion: DayCompletion {
        guard hasEntries else { return .noEntries }
        if isRest { return .rest }
        let met = metCount
        if met == 0 { return .noneMet }
        return met == goals.count ? .allMet : .someMet
    }
}

/// Every day's results, built from plain day totals (DESIGN.md §5.4, §5.5). A nutrient counts on a day the same
/// way it does for streaks, so the calendar's "all goals" days are exactly the streak days.
struct HistoryLog {
    /// All nutrients, deleted ones included, in display order.
    let nutrients: [HistoryNutrient]
    let calendar: Calendar
    /// Start of today.
    let today: Date

    private let totals: [Date: [UUID: Double]]
    private let excluded: [Date: Set<UUID>]

    /// - Parameters:
    ///   - totals: summed intake per nutrient, keyed by start of day. A day is present iff something was logged.
    ///   - exclusions: nutrients excluded per day, keyed by start of day.
    init(nutrients: [HistoryNutrient], totals: [Date: [UUID: Double]], exclusions: [Date: Set<UUID>] = [:],
         today: Date, calendar: Calendar = .current) {
        self.nutrients = nutrients
        self.totals = totals
        self.excluded = exclusions
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
    }

    func day(_ date: Date) -> HistoryDay {
        let start = calendar.startOfDay(for: date)
        let dayTotals = totals[start] ?? [:]
        let excludedIDs = excluded[start] ?? []

        func goal(_ nutrient: HistoryNutrient) -> HistoryDay.Goal {
            let total = max(0, dayTotals[nutrient.id] ?? 0)
            let met = GoalProgress(current: total, goalType: nutrient.goalType, target: nutrient.target,
                                   upperBound: nutrient.upperBound).countsAsMet
            return HistoryDay.Goal(nutrientID: nutrient.id, total: total, isMet: met)
        }

        let due = nutrients.filter { nutrient in
            !nutrient.isRemoved && calendar.startOfDay(for: nutrient.createdAt) <= start
                && NutrientCourse.includes(nutrient.endDate, gaps: nutrient.courseGaps, day: start,
                                           calendar: calendar)
                && nutrient.schedule.isCountedDay(start, calendar: calendar)
        }
        let counted = due.filter { !excludedIDs.contains($0.id) }
        let countedIDs = Set(counted.map(\.id))
        let others = nutrients.filter { dayTotals[$0.id] != nil && !countedIDs.contains($0.id) }

        return HistoryDay(date: start, goals: counted.map(goal), otherLogged: others.map(goal),
                          hasEntries: !dayTotals.isEmpty, isRest: due.isEmpty)
    }

    /// The most recent completed days with something logged, newest first. Rest days aren't results, so they're left
    /// out (the calendar still opens them).
    func recentDays(limit: Int) -> [HistoryDay] {
        totals.keys
            .filter { $0 < today }
            .sorted(by: >)
            .lazy
            .map(day)
            .filter { !$0.isRest }
            .prefix(limit)
            .map { $0 }
    }

    /// The nutrients with an entry on a day, even ones whose entries net to 0 (a log, then a decrement).
    func loggedNutrients(on date: Date) -> Set<UUID> {
        Set(totals[calendar.startOfDay(for: date)]?.keys.map { $0 } ?? [])
    }

    /// Whether any completed day has something logged.
    var hasPastEntries: Bool {
        totals.keys.contains { $0 < today }
    }

    /// Anything logged at all, today included: enough for Export data (All time includes today), not for History.
    var hasEntries: Bool { !totals.isEmpty }

    /// The first day there's anything to show: the earliest entry or nutrient, whichever came first.
    var firstDay: Date? {
        let earliestEntry = totals.keys.min()
        let earliestNutrient = nutrients.map { calendar.startOfDay(for: $0.createdAt) }.min()
        return [earliestEntry, earliestNutrient].compactMap { $0 }.min()
    }
}
