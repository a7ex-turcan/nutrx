import Foundation

/// The facts of one week, Monday to Sunday (nutrx Pro, docs/pro/PLAN.md phase 6). Pure: built from a `HistoryLog`,
/// so a goal counts on a day exactly as it does in History and for streaks. Nothing here is advice — it's what
/// happened, and `RecapText` / `RecapPhrasing` only ever put these facts into words.
struct WeeklyRecap: Equatable {
    /// One nutrient's week.
    struct NutrientWeek: Equatable {
        let id: UUID
        let name: String
        let goalType: GoalType
        /// Days it counted (created, not deleted, not excluded) up to the recap's last day.
        let daysCounted: Int
        let daysMet: Int
        /// Counted days it wasn't met, oldest first.
        let missedDays: [Date]
        /// Days it went over an "at most" limit or a range's maximum, oldest first.
        let overLimitDays: [Date]

        var hitRate: Double { daysCounted > 0 ? Double(daysMet) / Double(daysCounted) : 0 }
    }

    /// A nutrient taken a number of times a week (schedules, #132): how many of its days counted this week, judged
    /// only for a week wholly under that schedule.
    struct WeeklyGoal: Equatable {
        let id: UUID
        let name: String
        let met: Int
        let times: Int
    }

    /// The weekday missed most over the last four weeks ("Sunday · 3 of the last 4 weeks").
    struct WeekdayMiss: Equatable {
        /// `Calendar` weekday, 1 = Sunday … 7 = Saturday.
        let weekday: Int
        let missed: Int
        let weeks: Int
    }

    /// The streak at the end of this week and of the week before.
    struct StreakChange: Equatable {
        let now: Int
        let previous: Int
    }

    /// Monday, start of day.
    let weekStart: Date
    /// The last day counted: Sunday, or yesterday while the week is still running. A day counts only once it's over,
    /// so on Sunday evening the recap covers Monday to Saturday and adds Sunday on Monday; an unfinished day never
    /// reads as missed.
    let lastDay: Date
    /// Monday to Sunday: every goal met that day (the hero ring's lit segments). Days not counted are false.
    let fullDayFlags: [Bool]
    /// The week's days that aren't rest days (schedules, #132): the hero ring's segments. 7 without schedules.
    var dayCount = 7
    let goalsMet: Int
    let goalsCounted: Int
    /// Counted days with anything logged.
    let daysLogged: Int
    /// Days this week with anything logged, today included ("You've logged 3 days so far").
    let daysLoggedSoFar: Int
    /// Every nutrient's week, in display order.
    let nutrients: [NutrientWeek]
    let steadiest: NutrientWeek?
    let slipped: NutrientWeek?
    /// The nutrient that went over its limit on the most days.
    let overLimit: NutrientWeek?
    let weakestWeekday: WeekdayMiss?
    /// nil with streaks turned off, or when there's no streak either week.
    let streak: StreakChange?
    /// Nutrients taken a number of times a week (#132), in display order. They're in the goal totals on the days
    /// they counted, but not in `nutrients` (a day-by-day hit rate would read 100 %, so no steadiest or slipped).
    var weekly: [WeeklyGoal] = []
    /// Whether the recap covers the whole week, Sunday included (it's built from Sunday evening, before Sunday ends).
    var isWeekOver = true

    var fullDays: Int { fullDayFlags.filter { $0 }.count }
    /// Something to sum up: a goal counted and something was logged.
    var hasData: Bool { goalsCounted > 0 && daysLogged > 0 }

    /// The weekday the weakest-day card looks back over.
    static let weekdayWindowWeeks = 4

    // MARK: - Building

    /// - Parameters:
    ///   - log: every day's results.
    ///   - names: nutrient names by id.
    ///   - date: any date in the week; the recap covers its Monday to Sunday.
    ///   - streaksEnabled: the user's Streaks setting; off leaves the streak out.
    static func build(log: HistoryLog, names: [UUID: String], week date: Date, streaksEnabled: Bool) -> WeeklyRecap {
        let calendar = log.calendar
        let weekStart = Self.weekStart(containing: date, calendar: calendar)
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let lastDay = min(sunday, yesterday)
        let weekDays = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }

        var flags: [Bool] = []
        var goalsMet = 0
        var goalsCounted = 0
        var daysLogged = 0
        var counted: [UUID: Int] = [:]
        var met: [UUID: Int] = [:]
        var missed: [UUID: [Date]] = [:]
        var over: [UUID: [Date]] = [:]
        let byID = Dictionary(log.nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Under a weekly schedule on any day this week (#132): counted only on met days, so judged by the week.
        let weeklyIDs = Set(log.nutrients.filter { nutrient in
            weekDays.contains { nutrient.schedule.weeklyTimes(on: $0, calendar: calendar) != nil }
        }.map(\.id))

        let daysLoggedSoFar = weekDays.filter { $0 <= log.today && log.day($0).hasEntries }.count
        for date in weekDays {
            guard date <= lastDay else {
                flags.append(false)
                continue
            }
            let day = log.day(date)
            flags.append(day.hasEntries && !day.goals.isEmpty && !day.isRest && day.completion == .allMet)
            if day.hasEntries { daysLogged += 1 }
            goalsCounted += day.goals.count
            // A day with nothing logged meets nothing, even an "at most" goal: not opening the app isn't a result.
            goalsMet += day.goals.filter { weeklyIDs.contains($0.nutrientID) && $0.isMet }.count
            for goal in day.goals where !weeklyIDs.contains(goal.nutrientID) {
                counted[goal.nutrientID, default: 0] += 1
                if day.hasEntries && goal.isMet {
                    met[goal.nutrientID, default: 0] += 1
                    goalsMet += 1
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

        let weekly = log.nutrients.compactMap { nutrient -> WeeklyGoal? in
            guard weeklyIDs.contains(nutrient.id),
                  let result = log.weekResult(of: nutrient.id, weekStarting: weekStart, through: lastDay) else { return nil }
            return WeeklyGoal(id: nutrient.id, name: names[nutrient.id] ?? "", met: result.met, times: result.times)
        }

        let weeks = log.nutrients.compactMap { nutrient -> NutrientWeek? in
            guard let days = counted[nutrient.id], days > 0 else { return nil }
            return NutrientWeek(id: nutrient.id, name: names[nutrient.id] ?? "", goalType: nutrient.goalType,
                                daysCounted: days, daysMet: met[nutrient.id] ?? 0,
                                missedDays: missed[nutrient.id] ?? [], overLimitDays: over[nutrient.id] ?? [])
        }

        let (steadiest, slipped, overLimit) = picks(weeks)

        return WeeklyRecap(
            weekStart: weekStart, lastDay: lastDay, fullDayFlags: flags,
            dayCount: weekDays.filter { !log.day($0).isRest }.count, goalsMet: goalsMet,
            goalsCounted: goalsCounted, daysLogged: daysLogged, daysLoggedSoFar: daysLoggedSoFar, nutrients: weeks,
            steadiest: steadiest,
            slipped: slipped, overLimit: overLimit,
            weakestWeekday: lastDay >= weekStart ? weakestWeekday(log: log, through: lastDay) : nil,
            streak: streaksEnabled ? streakChange(log: log, weekStart: weekStart, sunday: sunday) : nil,
            weekly: weekly, isWeekOver: lastDay >= sunday
        )
    }

    /// Steadiest: the best hit rate, with at least one day met (more days met on a tie, then display order).
    /// Slipped: another nutrient's lowest hit rate below that (more days missed on a tie, then display order).
    /// Over limit: the most days over a limit (display order on a tie).
    static func picks(_ weeks: [NutrientWeek]) -> (NutrientWeek?, NutrientWeek?, NutrientWeek?) {
        let order = Dictionary(weeks.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        func earlier(_ a: NutrientWeek, _ b: NutrientWeek) -> Bool { order[a.id, default: 0] < order[b.id, default: 0] }

        let steadiest = weeks.filter { $0.daysMet > 0 }.min { a, b in
            if a.hitRate != b.hitRate { return a.hitRate > b.hitRate }
            if a.daysMet != b.daysMet { return a.daysMet > b.daysMet }
            return earlier(a, b)
        }
        let ceiling = steadiest?.hitRate ?? 2
        let slipped = weeks.filter { $0.id != steadiest?.id && !$0.missedDays.isEmpty && $0.hitRate < ceiling }
            .min { a, b in
                if a.hitRate != b.hitRate { return a.hitRate < b.hitRate }
                if a.missedDays.count != b.missedDays.count { return a.missedDays.count > b.missedDays.count }
                return earlier(a, b)
            }
        let overLimit = weeks.filter { !$0.overLimitDays.isEmpty }.min { a, b in
            if a.overLimitDays.count != b.overLimitDays.count { return a.overLimitDays.count > b.overLimitDays.count }
            return earlier(a, b)
        }
        return (steadiest, slipped, overLimit)
    }

    /// The weekday that most often wasn't a full day over the last four weeks, when one stands out: missed more
    /// often than any other weekday, at least twice, on at least half the weeks it was tracked, over three or more.
    static func weakestWeekday(log: HistoryLog, through lastDay: Date) -> WeekdayMiss? {
        let calendar = log.calendar
        var missed: [Int: Int] = [:]
        var tracked: [Int: Int] = [:]
        for offset in 0..<(weekdayWindowWeeks * 7) {
            let date = calendar.date(byAdding: .day, value: -offset, to: lastDay)!
            let day = log.day(date)
            guard !day.goals.isEmpty, let first = log.firstDay, date >= first else { continue }
            let weekday = calendar.component(.weekday, from: date)
            tracked[weekday, default: 0] += 1
            if !(day.hasEntries && day.completion == .allMet) { missed[weekday, default: 0] += 1 }
        }
        guard let top = missed.max(by: { $0.value < $1.value }),
              missed.values.filter({ $0 == top.value }).count == 1,
              top.value >= 2, let weeks = tracked[top.key], weeks >= 3, top.value * 2 >= weeks else { return nil }
        return WeekdayMiss(weekday: top.key, missed: top.value, weeks: weeks)
    }

    /// The streak through this week's Sunday (or yesterday, while the week is running) and through the Sunday before.
    /// (Its own `yesterday` cut-off: the same as `lastDay`.)
    static func streakChange(log: HistoryLog, weekStart: Date, sunday: Date) -> StreakChange? {
        let calendar = log.calendar
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let now = streak(log: log, endingOn: min(sunday, yesterday))
        let previousSunday = calendar.date(byAdding: .day, value: -1, to: weekStart)!
        let previous = streak(log: log, endingOn: min(previousSunday, yesterday))
        return now == 0 && previous == 0 ? nil : StreakChange(now: now, previous: previous)
    }

    /// Consecutive full days ending on `day` — the same days `StreakService` counts, stepping over rest days.
    static func streak(log: HistoryLog, endingOn day: Date) -> Int {
        var count = 0
        var date = day
        while let first = log.firstDay, date >= first {
            let result = log.day(date)
            if !result.isRest {
                guard result.hasEntries, !result.goals.isEmpty, result.completion == .allMet else { break }
                count += 1
            }
            date = log.calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    // MARK: - Weeks

    /// Recap weeks run Monday to Sunday whatever the locale's first weekday, so the recap lands on Sunday evening.
    static func weekStart(containing date: Date, calendar: Calendar) -> Date {
        // The same weeks as weekly schedules (#132), so the two can't drift apart.
        NutrientSchedule.weekStart(of: date, calendar: calendar)
    }

    /// When a week's recap is ready: its Sunday at 18:00.
    static func releaseDate(ofWeekStarting weekStart: Date, calendar: Calendar) -> Date {
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        return calendar.date(bySettingHour: releaseHour, minute: 0, second: 0, of: sunday)!
    }

    static let releaseHour = 18

    /// The newest week with a recap at `now`: this week from Sunday 18:00, else last week.
    static func latestWeek(at now: Date, calendar: Calendar) -> Date {
        let thisWeek = weekStart(containing: now, calendar: calendar)
        return now >= releaseDate(ofWeekStarting: thisWeek, calendar: calendar)
            ? thisWeek
            : calendar.date(byAdding: .day, value: -7, to: thisWeek)!
    }
}
