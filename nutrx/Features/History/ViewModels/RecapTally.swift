import Foundation

/// The day-by-day sums a recap is built from over a run of days (a week, a month): full days, goals met and counted,
/// days logged, and each nutrient's counted, met, missed and over-limit days. Pure. `WeeklyRecap` and `MonthlyRecap`
/// share it, so a goal counts the same in both, and as in History and for streaks (it all comes from `HistoryLog`).
struct RecapTally {
    /// Per day in `days`: every goal met. False for a day after `lastDay`, which hasn't counted yet.
    var fullDayFlags: [Bool] = []
    /// Per day in `days`: counted and something was due, so not a rest day (#132) or a day before anything was
    /// tracked. What a full day is out of.
    var dueDayFlags: [Bool] = []
    var goalsMet = 0
    var goalsCounted = 0
    /// Counted days with anything logged.
    var daysLogged = 0
    /// Counted days with at least one goal: how much the period says anything about.
    var daysWithGoals = 0
    /// Every nutrient counted day by day, in display order.
    var nutrients: [WeeklyRecap.NutrientWeek] = []
    /// Under a weekly schedule (#132) on any of the days: counted only on met days, so judged by the week and not in
    /// `nutrients` (a day-by-day hit rate would read 100 %).
    var weeklyIDs: Set<UUID> = []

    var fullDays: Int { fullDayFlags.filter { $0 }.count }

    static func make(log: HistoryLog, names: [UUID: String], days: [Date], lastDay: Date) -> RecapTally {
        let calendar = log.calendar
        var tally = RecapTally()
        tally.weeklyIDs = Set(log.nutrients.filter { nutrient in
            days.contains { nutrient.schedule.weeklyTimes(on: $0, calendar: calendar) != nil }
        }.map(\.id))
        var counted: [UUID: Int] = [:]
        var met: [UUID: Int] = [:]
        var missed: [UUID: [Date]] = [:]
        var over: [UUID: [Date]] = [:]
        let byID = Dictionary(log.nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for date in days {
            guard date <= lastDay else {
                tally.fullDayFlags.append(false)
                tally.dueDayFlags.append(false)
                continue
            }
            let day = log.day(date)
            tally.dueDayFlags.append(!day.goals.isEmpty && !day.isRest)
            tally.fullDayFlags.append(day.hasEntries && !day.goals.isEmpty && !day.isRest && day.completion == .allMet)
            if day.hasEntries { tally.daysLogged += 1 }
            if !day.goals.isEmpty { tally.daysWithGoals += 1 }
            tally.goalsCounted += day.goals.count
            // A day with nothing logged meets nothing, even an "at most" goal: not opening the app isn't a result.
            tally.goalsMet += day.goals.filter { tally.weeklyIDs.contains($0.nutrientID) && $0.isMet }.count
            for goal in day.goals where !tally.weeklyIDs.contains(goal.nutrientID) {
                counted[goal.nutrientID, default: 0] += 1
                if day.hasEntries && goal.isMet {
                    met[goal.nutrientID, default: 0] += 1
                    tally.goalsMet += 1
                } else {
                    missed[goal.nutrientID, default: []].append(date)
                }
                if let nutrient = byID[goal.nutrientID],
                   GoalProgress(current: goal.total, goalType: nutrient.goalType, target: nutrient.target,
                                upperBound: nutrient.upperBound).status == .overLimit {
                    over[goal.nutrientID, default: []].append(date)
                }
            }
        }

        tally.nutrients = log.nutrients.compactMap { nutrient in
            guard let days = counted[nutrient.id], days > 0 else { return nil }
            return WeeklyRecap.NutrientWeek(
                id: nutrient.id, name: names[nutrient.id] ?? "", goalType: nutrient.goalType, daysCounted: days,
                daysMet: met[nutrient.id] ?? 0, missedDays: missed[nutrient.id] ?? [],
                overLimitDays: over[nutrient.id] ?? [])
        }
        return tally
    }
}
