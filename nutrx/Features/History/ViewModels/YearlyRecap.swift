import Foundation

/// The facts of one calendar year (nutrx Pro, #136, docs/pro/RECAPS.md §3). Pure: each month is tallied as its
/// monthly recap is (`RecapTally`), and the year adds them up, so its goals and full days are its months' and a goal
/// counts as it does in History. The whole year from 1 January; until then, the year so far. Facts only:
/// `YearlyRecapText` puts them into words.
struct YearlyRecap: Equatable {
    /// One month's bar: its goals-met rate, as its monthly recap has it.
    struct Month: Equatable {
        /// The 1st, start of day.
        let monthStart: Date
        let goalsMet: Int
        let goalsCounted: Int
        /// Days with at least one goal: what the best month needs enough of.
        let daysWithGoals: Int
        let daysLogged: Int
        /// The month's days through the year's last counted day.
        let daysElapsed: Int

        /// Nil for a month with nothing counted, drawn as an empty bar.
        var rate: Double? { goalsCounted > 0 ? Double(goalsMet) / Double(goalsCounted) : nil }
    }

    /// A nutrient first tracked this year: "You started tracking Magnesium in April".
    struct Started: Equatable {
        let id: UUID
        let name: String
        /// The 1st of the month it was added.
        let month: Date
    }

    /// 1 January, start of day.
    let yearStart: Date
    /// The last day counted: 31 December, or yesterday while the year runs.
    let lastDay: Date
    /// Whether the whole year has counted ("2026", not "2026 so far").
    let isYearOver: Bool
    /// January to December.
    let months: [Month]
    let fullDays: Int
    /// Counted days that aren't rest days (#132): what the full days are out of.
    let dayCount: Int
    let goalsMet: Int
    let goalsCounted: Int
    let daysLogged: Int
    /// The year's days through `lastDay`.
    let daysElapsed: Int
    /// Days this year with anything logged, today included.
    let daysLoggedSoFar: Int
    /// Every nutrient's year (its months added up), in display order.
    let nutrients: [WeeklyRecap.NutrientWeek]
    /// Among nutrients counted on at least `steadiestMinimumDays` days.
    let steadiest: WeeklyRecap.NutrientWeek?
    /// The month with the highest rate among those with at least `bestMonthMinimumDays` counted days, when it stands
    /// out: two months qualify and no other reads the same whole percent.
    let bestMonth: Month?
    /// The month with the most days logged; nil unless two months have something logged.
    let mostLogged: Month?
    /// The longest run of full days inside the year; nil with Streaks off or under 2 days.
    let longestStreak: Int?
    /// The user's first year: everything tracked was added this year, starting in this month.
    let firstMonth: Date?
    /// Otherwise, nutrients added this year (not removed since), oldest first.
    let started: [Started]
    var weekly: [MonthlyRecap.WeeklyGoal] = []

    var rate: Double? { goalsCounted > 0 ? Double(goalsMet) / Double(goalsCounted) : nil }
    /// Something to sum up: a goal counted and something was logged.
    var hasData: Bool { goalsCounted > 0 && daysLogged > 0 }

    static let steadiestMinimumDays = 30
    static let bestMonthMinimumDays = 10
    static let releaseHour = 18

    // MARK: - Building

    /// - Parameters:
    ///   - date: any date in the year.
    ///   - streaksEnabled: the user's Streaks setting; off leaves the longest streak out.
    static func build(log: HistoryLog, names: [UUID: String], year date: Date, streaksEnabled: Bool) -> YearlyRecap {
        let calendar = log.calendar
        let yearStart = Self.yearStart(containing: date, calendar: calendar)
        let yearDays = days(ofYearStarting: yearStart, calendar: calendar)
        let yearEnd = yearDays.last!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let lastDay = min(yearEnd, yesterday)
        let counted = yearDays.filter { $0 <= lastDay }

        var months: [Month] = []
        var tallies: [RecapTally] = []
        for offset in 0..<12 {
            let monthStart = calendar.date(byAdding: .month, value: offset, to: yearStart)!
            let monthDays = MonthlyRecap.days(ofMonthStarting: monthStart, calendar: calendar)
            let tally = RecapTally.make(log: log, names: names, days: monthDays, lastDay: lastDay)
            tallies.append(tally)
            months.append(Month(monthStart: monthStart, goalsMet: tally.goalsMet, goalsCounted: tally.goalsCounted,
                                daysWithGoals: tally.daysWithGoals, daysLogged: tally.daysLogged,
                                daysElapsed: monthDays.filter { $0 <= lastDay }.count))
        }
        let nutrients = merged(tallies.map(\.nutrients), order: log.nutrients.map(\.id))
        let steadiest = WeeklyRecap.picks(nutrients.filter { $0.daysCounted >= steadiestMinimumDays }).0
        let (firstMonth, started) = beginnings(log: log, names: names, yearStart: yearStart, lastDay: lastDay)

        return YearlyRecap(
            yearStart: yearStart, lastDay: lastDay, isYearOver: lastDay >= yearEnd, months: months,
            fullDays: tallies.map(\.fullDays).reduce(0, +),
            dayCount: counted.filter { !log.day($0).isRest }.count,
            goalsMet: months.map(\.goalsMet).reduce(0, +), goalsCounted: months.map(\.goalsCounted).reduce(0, +),
            daysLogged: months.map(\.daysLogged).reduce(0, +), daysElapsed: counted.count,
            daysLoggedSoFar: yearDays.filter { $0 <= log.today && log.day($0).hasEntries }.count,
            nutrients: nutrients, steadiest: steadiest, bestMonth: bestMonth(months), mostLogged: mostLogged(months),
            longestStreak: streaksEnabled ? MonthlyRecap.bestStreak(log: log, days: counted) : nil,
            firstMonth: firstMonth, started: started,
            weekly: MonthlyRecap.weeklyGoals(log: log, names: names,
                                             ids: tallies.reduce(into: Set<UUID>()) { $0.formUnion($1.weeklyIDs) },
                                             monthDays: yearDays, lastDay: lastDay)
        )
    }

    /// Each nutrient's months added up, in display order.
    static func merged(_ months: [[WeeklyRecap.NutrientWeek]], order: [UUID]) -> [WeeklyRecap.NutrientWeek] {
        var byID: [UUID: WeeklyRecap.NutrientWeek] = [:]
        for month in months {
            for nutrient in month {
                guard let sum = byID[nutrient.id] else {
                    byID[nutrient.id] = nutrient
                    continue
                }
                byID[nutrient.id] = WeeklyRecap.NutrientWeek(
                    id: sum.id, name: sum.name, goalType: sum.goalType,
                    daysCounted: sum.daysCounted + nutrient.daysCounted, daysMet: sum.daysMet + nutrient.daysMet,
                    missedDays: sum.missedDays + nutrient.missedDays,
                    overLimitDays: sum.overLimitDays + nutrient.overLimitDays)
            }
        }
        return order.compactMap { byID[$0] }
    }

    /// The best rate among months with enough counted days, when it stands out: nil unless two months qualify ("your
    /// best month" of one says nothing) and no other month reads the same whole percent (a 97% best month beside
    /// another 97%, or a year of 100% months, says nothing either).
    static func bestMonth(_ months: [Month]) -> Month? {
        let eligible = months.filter { $0.daysWithGoals >= bestMonthMinimumDays && $0.rate != nil }
        guard eligible.count >= 2, let best = eligible.max(by: { $0.rate! < $1.rate! }) else { return nil }
        let shown = wholePercent(best.rate)
        guard eligible.filter({ wholePercent($0.rate) == shown }).count == 1 else { return nil }
        return best
    }

    /// A rate as the words show it: 0.969 → 97.
    static func wholePercent(_ rate: Double?) -> Int { Int(((rate ?? 0) * 100).rounded()) }

    /// The month with the most days logged, the earliest on a tie; nil unless two months have something logged.
    static func mostLogged(_ months: [Month]) -> Month? {
        let logged = months.filter { $0.daysLogged > 0 }
        guard logged.count >= 2 else { return nil }
        return logged.max { a, b in a.daysLogged != b.daysLogged ? a.daysLogged < b.daysLogged : a.monthStart > b.monthStart }
    }

    /// The user's first year (everything, removed nutrients too, added this year): the month it started. Otherwise
    /// the nutrients added this year and still tracked, oldest first.
    static func beginnings(log: HistoryLog, names: [UUID: String], yearStart: Date,
                           lastDay: Date) -> (firstMonth: Date?, started: [Started]) {
        let calendar = log.calendar
        let tracked = log.nutrients.filter { calendar.startOfDay(for: $0.createdAt) <= lastDay }
        guard let earliest = tracked.map(\.createdAt).min() else { return (nil, []) }
        if earliest >= yearStart {
            return (MonthlyRecap.monthStart(containing: earliest, calendar: calendar), [])
        }
        let started = tracked
            .filter { $0.createdAt >= yearStart && !$0.isRemoved }
            .sorted { $0.createdAt < $1.createdAt }
            .map { Started(id: $0.id, name: names[$0.id] ?? "",
                           month: MonthlyRecap.monthStart(containing: $0.createdAt, calendar: calendar)) }
        return (nil, started)
    }

    // MARK: - Years

    /// 1 January of the year containing `date`, start of day.
    static func yearStart(containing date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: date)).map { calendar.startOfDay(for: $0) }!
    }

    /// Every day of the year starting on `yearStart`, start of day.
    static func days(ofYearStarting yearStart: Date, calendar: Calendar) -> [Date] {
        let count = calendar.range(of: .day, in: .year, for: yearStart)?.count ?? 365
        return (0..<count).map { calendar.date(byAdding: .day, value: $0, to: yearStart)! }
    }

    /// When a year's recap notification goes out: 1 January at 18:00. The recap itself is whole from the 1st's start.
    static func releaseDate(ofYearStarting yearStart: Date, calendar: Calendar) -> Date {
        let next = calendar.date(byAdding: .year, value: 1, to: yearStart)!
        return calendar.date(bySettingHour: releaseHour, minute: 0, second: 0, of: next)!
    }

    /// The newest whole year at `now`: last year.
    static func latestYear(at now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .year, value: -1, to: yearStart(containing: now, calendar: calendar))!
    }
}
