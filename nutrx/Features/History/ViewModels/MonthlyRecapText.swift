import Foundation

/// The monthly recap's words (#136, docs/pro/RECAPS.md §4), from `MonthlyRecap`'s facts only. Like the week's
/// (`RecapText`): a template summary that runs everywhere, which `RecapPhrasing` may reword, checked against these
/// facts. It describes and never advises.
struct MonthlyRecapText: RecapWording {
    let recap: MonthlyRecap
    let calendar: Calendar

    init(_ recap: MonthlyRecap, calendar: Calendar = .current) {
        self.recap = recap
        self.calendar = calendar
    }

    let period = RecapPhrasing.Period.month
    var steadiestName: String? { recap.steadiest?.name }
    var cacheKey: String { "month-\(year)-\(String(format: "%02d", month))" }

    // MARK: - Hero

    /// "October".
    var monthName: String { calendar.standaloneMonthSymbols[month - 1] }

    /// "October 2026", or "October so far" while the month runs.
    var range: String { recap.isMonthOver ? "\(monthName) \(year)" : "\(monthName) so far" }

    /// "412 of 540 goals met".
    var headline: String { "\(recap.goalsMet) of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted)) met" }

    /// The goals-met rate, whole percent.
    var percent: Int { Int(((recap.rate ?? 0) * 100).rounded()) }

    /// The ring's centre: "18/30" over "full days", out of the counted days that weren't rest days.
    var ringValue: String { "\(recap.fullDays)/\(recap.dayCount)" }
    let ringLabel = "full days"

    /// "In October you met 76% of your goals, with 18 full days. Vitamin D was your steadiest, 31 of 31 days. …"
    var summary: String {
        guard recap.hasData else { return "Nothing was logged \(recap.isMonthOver ? "in" : "so far in") \(monthName)." }
        let full = recap.fullDays == 0 ? "no full days" : days(recap.fullDays, "full day")
        // The month so far reads in the present (docs/pro/RECAPS.md §4).
        let over = recap.isMonthOver
        var sentences = [over
            ? "In \(monthName) you met \(percent)% of your goals, with \(full)."
            : "So far in \(monthName) you've met \(percent)% of your goals, with \(full)."]
        if let steadiest = recap.steadiest {
            sentences.append("\(steadiest.name) \(over ? "was" : "is") your steadiest, "
                + "\(steadiest.daysMet) of \(steadiest.daysCounted) days.")
        }
        let overLimit = recap.overLimit
        if let slipped = recap.slipped, slipped.id != overLimit?.id {
            sentences.append("\(slipped.name) \(over ? "slipped" : "has slipped") \(when(slipped.missedDays)).")
        }
        if let overLimit {
            let limit = overLimit.goalType == .range ? "its range" : "your limit"
            sentences.append("\(overLimit.name) \(over ? "went" : "has gone") over \(limit) \(when(overLimit.overLimitDays)).")
        }
        // Times a week (#132): judged by the week.
        for goal in recap.weekly {
            sentences.append("\(goal.name) \(over ? "met" : "has met") its weekly goal in "
                + "\(goal.weeksMet) of \(days(goal.weeks, "week")).")
        }
        if let streak = recap.bestStreak {
            sentences.append("Your best run \(over ? "was" : "is") \(streak) days in a row.")
        }
        if let comparison = recap.comparison {
            sentences.append("\(comparisonLine(comparison)).")
        }
        return sentences.joined(separator: " ")
    }

    /// "Up from 68% in September", "Down from 81% in September".
    func comparisonLine(_ comparison: MonthlyRecap.Comparison) -> String {
        let previous = Int((comparison.rate * 100).rounded())
        let name = calendar.standaloneMonthSymbols[calendar.component(.month, from: comparison.month) - 1]
        return "\((recap.rate ?? 0) >= comparison.rate ? "Up" : "Down") from \(previous)% in \(name)"
    }

    // MARK: - Fact cards

    /// Steadiest, Slipped, Day you tend to miss, Best run and Against last month: whichever have something to say.
    var cards: [RecapText.Card] {
        var cards: [RecapText.Card] = []
        if let steadiest = recap.steadiest {
            cards.append(.init(kind: .steadiest, label: "Steadiest", value: steadiest.name,
                               detail: "\(steadiest.daysMet) of \(steadiest.daysCounted) days", nutrientID: steadiest.id))
        }
        if let slipped = recap.slipped {
            cards.append(.init(kind: .slipped, label: "Slipped", value: slipped.name,
                               detail: "Missed \(when(slipped.missedDays))", nutrientID: slipped.id))
        }
        if let miss = recap.weakestWeekday {
            let weekday = calendar.weekdaySymbols[miss.weekday - 1]
            cards.append(.init(kind: .weekday, label: "Day you tend to miss", value: weekday,
                               detail: "Missed \(RecapText.together("\(miss.missed) of \(miss.weeks) \(weekday)s"))",
                               nutrientID: nil))
        }
        if let streak = recap.bestStreak {
            cards.append(.init(kind: .streak, label: "Best run", value: days(streak, "day"),
                               detail: "\(RecapText.together("Every goal met")), \(RecapText.together("in a row"))",
                               nutrientID: nil))
        }
        if let comparison = recap.comparison {
            cards.append(.init(kind: .comparison, label: "Goals met", value: "\(percent)%",
                               detail: comparisonLine(comparison), nutrientID: nil))
        }
        return cards
    }

    // MARK: - Elsewhere

    /// Today's card: "412 of 540 goals · Vitamin D steadiest" (the first number bold), breaking only at the dot.
    var todayLine: String {
        let goals = RecapText.together("**\(recap.goalsMet)** of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted))")
        return recap.steadiest.map { "\(goals) · \(RecapText.together("\($0.name) steadiest"))" } ?? goals
    }

    /// History's row: "Latest: October · 412 of 540 goals".
    var historyLine: String {
        "Latest: \(RecapText.together(monthName)) · \(RecapText.together("\(recap.goalsMet) of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted))"))"
    }

    /// "Your October in nutrx".
    var notificationTitle: String { "Your \(monthName) in nutrx" }

    /// "You met 76% of your goals in October. Vitamin D was your steadiest."
    var notificationBody: String {
        let goals = "You met \(percent)% of your goals in \(monthName)."
        return recap.steadiest.map { "\(goals) \($0.name) was your steadiest." } ?? goals
    }

    /// Set up before the month's facts are in: no numbers that could be out of date.
    var notificationBodyWithoutFacts: String { "See what you hit in \(monthName) and what slipped." }

    /// Before any month has something in it: "Your first monthly recap arrives on 1 November".
    static func firstTitle(nextMonthStart: Date, calendar: Calendar = .current) -> String {
        let month = calendar.standaloneMonthSymbols[calendar.component(.month, from: nextMonthStart) - 1]
        return "Your first monthly recap arrives on 1 \(month)"
    }

    static func firstBody(daysLogged: Int) -> String {
        switch daysLogged {
        case 0: "Log this month and the recap on the 1st will sum it up."
        case 1: "You've logged 1 day so far. The recap on the 1st will cover the whole month."
        default: "You've logged \(daysLogged) days so far. The recap on the 1st will cover the whole month."
        }
    }

    // MARK: - Pieces

    /// "on Sundays" when every miss fell on one weekday (twice or more), "on weekends" when on Saturdays and Sundays
    /// only (three times or more, so more than one weekend), else "on 4 days" / "on 1 day".
    func when(_ dates: [Date]) -> String {
        let weekdays = Set(dates.map { calendar.component(.weekday, from: $0) })
        if dates.count >= 3, weekdays == [1, 7] { return "on weekends" }
        if dates.count >= 2, weekdays.count == 1, let weekday = weekdays.first {
            return "on \(calendar.weekdaySymbols[weekday - 1])s"
        }
        return "on \(days(dates.count, "day"))"
    }

    func days(_ count: Int, _ unit: String) -> String { count == 1 ? "1 \(unit)" : "\(count) \(unit)s" }

    private var month: Int { calendar.component(.month, from: recap.monthStart) }
    private var year: Int { calendar.component(.year, from: recap.monthStart) }

    /// Every number the month's words may use, for checking a reworded summary.
    var factNumbers: Set<Int> {
        var numbers: Set<Int> = [recap.goalsMet, recap.goalsCounted, recap.fullDays, recap.dayCount, recap.daysLogged,
                                 recap.daysElapsed, percent, year, 1]
        if let comparison = recap.comparison { numbers.insert(Int((comparison.rate * 100).rounded())) }
        if let streak = recap.bestStreak { numbers.insert(streak) }
        for goal in recap.weekly { numbers.formUnion([goal.weeksMet, goal.weeks]) }
        for month in recap.nutrients {
            numbers.formUnion([month.daysMet, month.daysCounted, month.missedDays.count, month.overLimitDays.count])
        }
        if let miss = recap.weakestWeekday { numbers.formUnion([miss.missed, miss.weeks]) }
        // Numbers inside names ("Vitamin B12", "Omega-3").
        for name in recap.nutrients.map(\.name) + recap.weekly.map(\.name) {
            numbers.formUnion(name.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
        }
        return numbers
    }
}
