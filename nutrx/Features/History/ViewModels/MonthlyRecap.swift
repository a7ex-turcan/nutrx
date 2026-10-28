import Foundation

/// The facts of one calendar month (nutrx Pro, #136, docs/pro/RECAPS.md §2). Pure: built from a `HistoryLog` through
/// the same `RecapTally` as the week, so a goal counts as it does in History and for streaks. Facts only:
/// `MonthlyRecapText` puts them into words.
struct MonthlyRecap: Equatable {
    /// A nutrient taken a number of times a week (#132): its weeks met in the month, counting only weeks wholly
    /// inside the month, under that schedule and over.
    struct WeeklyGoal: Equatable {
        let id: UUID
        let name: String
        let weeksMet: Int
        let weeks: Int
    }

    /// The month before, for "Up from 68 % in September".
    struct Comparison: Equatable {
        let month: Date
        let rate: Double
    }

    /// The 1st, start of day.
    let monthStart: Date
    /// The last day counted: the month's last day, or yesterday while the month is still running.
    let lastDay: Date
    /// Whether the whole month has counted ("October", not "October so far").
    let isMonthOver: Bool
    /// The 1st to the last day: every goal met that day (the month grid's lit days). False after `lastDay`.
    let fullDayFlags: [Bool]
    let fullDays: Int
    /// Counted days that aren't rest days (#132): what the full days are out of.
    let dayCount: Int
    let goalsMet: Int
    let goalsCounted: Int
    let daysLogged: Int
    /// The month's days through `lastDay` ("Logged 27 of 31 days").
    let daysElapsed: Int
    /// Days this month with anything logged, today included.
    let daysLoggedSoFar: Int
    /// Every nutrient's month, in display order.
    let nutrients: [WeeklyRecap.NutrientWeek]
    let steadiest: WeeklyRecap.NutrientWeek?
    let slipped: WeeklyRecap.NutrientWeek?
    let overLimit: WeeklyRecap.NutrientWeek?
    /// The weekday most often not a full day this month, when one stands out.
    let weakestWeekday: WeeklyRecap.WeekdayMiss?
    /// The longest run of full days inside the month; nil with Streaks off or under 2 days.
    let bestStreak: Int?
    /// Last month's goals-met rate, when it says something (§2: 7 counted days, 3 points apart).
    let comparison: Comparison?
    var weekly: [WeeklyGoal] = []

    var rate: Double? { goalsCounted > 0 ? Double(goalsMet) / Double(goalsCounted) : nil }
    /// Something to sum up: a goal counted and something was logged.
    var hasData: Bool { goalsCounted > 0 && daysLogged > 0 }

    /// Last month needs this many counted days for the comparison, and this big a gap (points).
    static let comparisonMinimumDays = 7
    /// The month's picks need this many counted days.
    static let pickMinimumDays = 7
    static let comparisonMinimumGap = 0.03
    static let releaseHour = 18

    // MARK: - Building

    /// - Parameters:
    ///   - date: any date in the month.
    ///   - streaksEnabled: the user's Streaks setting; off leaves the best streak out.
    static func build(log: HistoryLog, names: [UUID: String], month date: Date, streaksEnabled: Bool) -> MonthlyRecap {
        let calendar = log.calendar
        let monthStart = Self.monthStart(containing: date, calendar: calendar)
        let monthDays = days(ofMonthStarting: monthStart, calendar: calendar)
        let monthEnd = monthDays.last!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let lastDay = min(monthEnd, yesterday)
        let tally = RecapTally.make(log: log, names: names, days: monthDays, lastDay: lastDay)
        let counted = monthDays.filter { $0 <= lastDay }
        // Picks only among nutrients counted on enough days: one added on the 29th (2 of 2) can't outrank 28 of 30.
        let (steadiest, slipped, overLimit) = WeeklyRecap.picks(tally.nutrients.filter { $0.daysCounted >= pickMinimumDays })

        return MonthlyRecap(
            monthStart: monthStart, lastDay: lastDay, isMonthOver: lastDay >= monthEnd,
            fullDayFlags: tally.fullDayFlags, fullDays: tally.fullDays,
            dayCount: counted.filter { !log.day($0).isRest }.count, goalsMet: tally.goalsMet,
            goalsCounted: tally.goalsCounted, daysLogged: tally.daysLogged, daysElapsed: counted.count,
            daysLoggedSoFar: monthDays.filter { $0 <= log.today && log.day($0).hasEntries }.count,
            nutrients: tally.nutrients, steadiest: steadiest, slipped: slipped, overLimit: overLimit,
            weakestWeekday: weakestWeekday(log: log, days: counted),
            bestStreak: streaksEnabled ? bestStreak(log: log, days: counted) : nil,
            comparison: comparison(log: log, names: names, before: monthStart, rate: tally.goalsCounted > 0
                                       ? Double(tally.goalsMet) / Double(tally.goalsCounted) : nil),
            weekly: weeklyGoals(log: log, names: names, ids: tally.weeklyIDs, monthDays: monthDays, lastDay: lastDay)
        )
    }

    /// The weekday most often not a full day among `days`: missed at least twice, and more than any other weekday.
    static func weakestWeekday(log: HistoryLog, days: [Date]) -> WeeklyRecap.WeekdayMiss? {
        var missed: [Int: Int] = [:]
        var tracked: [Int: Int] = [:]
        for date in days {
            let day = log.day(date)
            guard !day.goals.isEmpty, !day.isRest else { continue }
            let weekday = log.calendar.component(.weekday, from: date)
            tracked[weekday, default: 0] += 1
            if !(day.hasEntries && day.completion == .allMet) { missed[weekday, default: 0] += 1 }
        }
        guard let top = missed.max(by: { $0.value < $1.value }), top.value >= 2,
              missed.values.filter({ $0 == top.value }).count == 1 else { return nil }
        return WeeklyRecap.WeekdayMiss(weekday: top.key, missed: top.value, weeks: tracked[top.key] ?? top.value)
    }

    /// The longest run of full days among `days`, stepping over rest days as `StreakService` does; nil under 2.
    static func bestStreak(log: HistoryLog, days: [Date]) -> Int? {
        var best = 0
        var run = 0
        for date in days {
            let day = log.day(date)
            if day.isRest { continue }
            if day.hasEntries && !day.goals.isEmpty && day.completion == .allMet {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best >= 2 ? best : nil
    }

    /// Last month's goals-met rate, when it had enough counted days and the gap is big enough to mention.
    static func comparison(log: HistoryLog, names: [UUID: String], before monthStart: Date,
                           rate: Double?) -> Comparison? {
        let calendar = log.calendar
        guard let rate, let previousStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else { return nil }
        let previousDays = days(ofMonthStarting: previousStart, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let previous = RecapTally.make(log: log, names: names, days: previousDays,
                                       lastDay: min(previousDays.last!, yesterday))
        guard previous.daysWithGoals >= comparisonMinimumDays, previous.goalsCounted > 0 else { return nil }
        let previousRate = Double(previous.goalsMet) / Double(previous.goalsCounted)
        guard abs(rate - previousRate) >= comparisonMinimumGap else { return nil }
        return Comparison(month: previousStart, rate: previousRate)
    }

    /// Weekly nutrients' weeks wholly inside the month and over by `lastDay`, judged as Today and History do.
    static func weeklyGoals(log: HistoryLog, names: [UUID: String], ids: Set<UUID>, monthDays: [Date],
                            lastDay: Date) -> [WeeklyGoal] {
        let calendar = log.calendar
        let mondays = monthDays.filter {
            NutrientSchedule.weekStart(of: $0, calendar: calendar) == $0
                && calendar.date(byAdding: .day, value: 6, to: $0)! <= min(monthDays.last!, lastDay)
        }
        return log.nutrients.compactMap { nutrient in
            guard ids.contains(nutrient.id) else { return nil }
            let results = mondays.compactMap { log.weekResult(of: nutrient.id, weekStarting: $0) }
            guard !results.isEmpty else { return nil }
            return WeeklyGoal(id: nutrient.id, name: names[nutrient.id] ?? "",
                              weeksMet: results.filter(\.isDone).count, weeks: results.count)
        }
    }

    // MARK: - Months

    /// The 1st of the month containing `date`, start of day.
    static func monthStart(containing date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)).map { calendar.startOfDay(for: $0) }!
    }

    /// Every day of the month starting on `monthStart`, start of day.
    static func days(ofMonthStarting monthStart: Date, calendar: Calendar) -> [Date] {
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        return (0..<count).map { calendar.date(byAdding: .day, value: $0, to: monthStart)! }
    }

    /// When a month's recap notification goes out: the next month's 1st at 18:00. The recap itself is whole from the
    /// 1st's start, once every day of the month is over.
    static func releaseDate(ofMonthStarting monthStart: Date, calendar: Calendar) -> Date {
        let next = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        return calendar.date(bySettingHour: releaseHour, minute: 0, second: 0, of: next)!
    }

    /// The newest whole month at `now`: last month.
    static func latestMonth(at now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: -1, to: monthStart(containing: now, calendar: calendar))!
    }
}
