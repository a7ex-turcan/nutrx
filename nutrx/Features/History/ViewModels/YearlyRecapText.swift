import Foundation

/// The yearly recap's words (#136, docs/pro/RECAPS.md §4), from `YearlyRecap`'s facts only. Like the week's and the
/// month's: a template summary that runs everywhere, which `RecapPhrasing` may reword, checked against these facts.
/// Past tense for a finished year, present for the year so far. It describes and never advises.
struct YearlyRecapText: RecapWording {
    let recap: YearlyRecap
    let calendar: Calendar

    init(_ recap: YearlyRecap, calendar: Calendar = .current) {
        self.recap = recap
        self.calendar = calendar
    }

    let period = RecapPhrasing.Period.year
    var steadiestName: String? { recap.steadiest?.name }
    var cacheKey: String { "year-\(year)" }

    // MARK: - Hero

    /// "2026".
    var yearName: String { "\(year)" }

    /// "2026", or "2026 so far" while the year runs.
    var range: String { recap.isYearOver ? yearName : "\(yearName) so far" }

    /// "3,960 of 5,400 goals met".
    var headline: String {
        "\(number(recap.goalsMet)) of \(number(recap.goalsCounted)) \(GoalProgress.goals(recap.goalsCounted)) met"
    }

    /// The goals-met rate, whole percent.
    var percent: Int { Self.percent(recap.rate) }

    let ringLabel = "full days"

    /// "In 2026 you logged on 311 days and met 73% of your goals. Your best month was May, at 92%. …"
    var summary: String {
        guard recap.hasData else { return "Nothing was logged \(recap.isYearOver ? "in" : "so far in") \(yearName)." }
        let over = recap.isYearOver
        let logged = days(recap.daysLogged, "day")
        var sentences = [over
            ? "In \(yearName) you logged on \(logged) and met \(percent)% of your goals."
            : "So far in \(yearName) you've logged on \(logged) and met \(percent)% of your goals."]
        if let best = recap.bestMonth {
            sentences.append("Your best month \(over ? "was" : "is") \(monthName(best.monthStart)), at \(Self.percent(best.rate))%.")
        }
        if let steadiest = recap.steadiest {
            sentences.append("\(steadiest.name) \(over ? "was" : "is") your steadiest, "
                + "\(steadiest.daysMet) of \(steadiest.daysCounted) days.")
        }
        // Times a week (#132): judged by the week.
        for goal in recap.weekly {
            sentences.append("\(goal.name) \(over ? "met" : "has met") its weekly goal in "
                + "\(goal.weeksMet) of \(days(goal.weeks, "week")).")
        }
        if let streak = recap.longestStreak {
            sentences.append("Your longest run \(over ? "was" : "is") \(streak) days in a row.")
        }
        if let started = startedSentence {
            sentences.append(started)
        }
        return sentences.joined(separator: " ")
    }

    /// "You started tracking in September." in a first year; else "You started tracking Magnesium in April." (two
    /// named, or "3 nutrients this year").
    private var startedSentence: String? {
        if let first = recap.firstMonth { return "You started tracking in \(monthName(first))." }
        switch recap.started.count {
        case 0: return nil
        case 1, 2:
            let parts = recap.started.map { "\($0.name) in \(monthName($0.month))" }
            return "You started tracking \(parts.joined(separator: " and "))."
        default: return "You started tracking \(recap.started.count) nutrients this year."
        }
    }

    // MARK: - Month by month

    /// "J", "F", … under the bars.
    func barLetter(_ month: YearlyRecap.Month) -> String {
        calendar.veryShortStandaloneMonthSymbols[calendar.component(.month, from: month.monthStart) - 1]
    }

    /// VoiceOver's reading of the bars: "January 80%, February nothing counted, …, May 92%, best", up to the last
    /// month that has begun.
    var barsAccessibilityValue: String {
        recap.months.filter { $0.daysElapsed > 0 }.map { month in
            let name = monthName(month.monthStart)
            guard let rate = month.rate else { return "\(name) nothing counted" }
            return "\(name) \(Self.percent(rate))%" + (month == recap.bestMonth ? ", best" : "")
        }.joined(separator: ", ")
    }

    // MARK: - Fact cards

    /// Best month, Steadiest, Longest run, Days logged and Since you started / New this year: whichever have
    /// something to say.
    var cards: [RecapText.Card] {
        var cards: [RecapText.Card] = []
        if let best = recap.bestMonth {
            cards.append(.init(kind: .bestMonth, label: "Best month", value: monthName(best.monthStart),
                               detail: "\(Self.percent(best.rate))% of goals met", nutrientID: nil))
        }
        if let steadiest = recap.steadiest {
            cards.append(.init(kind: .steadiest, label: "Steadiest", value: steadiest.name,
                               detail: "\(steadiest.daysMet) of \(steadiest.daysCounted) days", nutrientID: steadiest.id))
        }
        if let streak = recap.longestStreak {
            cards.append(.init(kind: .streak, label: "Longest run", value: days(streak, "day"),
                               detail: "\(RecapText.together("Every goal met")), \(RecapText.together("in a row"))",
                               nutrientID: nil))
        }
        if let most = recap.mostLogged {
            cards.append(.init(kind: .daysLogged, label: "Days logged", value: days(recap.daysLogged, "day"),
                               detail: "Most in \(monthName(most.monthStart)), \(RecapText.together("\(most.daysLogged) of \(most.daysElapsed)"))",
                               nutrientID: nil))
        }
        if let first = recap.firstMonth {
            cards.append(.init(kind: .started, label: "Since you started", value: monthName(first),
                               detail: "Your first year in nutrx", nutrientID: nil))
        } else if let only = recap.started.first, recap.started.count == 1 {
            cards.append(.init(kind: .started, label: "New this year", value: only.name,
                               detail: "Since \(monthName(only.month))", nutrientID: only.id))
        } else if !recap.started.isEmpty {
            cards.append(.init(kind: .started, label: "New this year", value: "\(recap.started.count) nutrients",
                               detail: list(recap.started.map(\.name)), nutrientID: nil))
        }
        return cards
    }

    // MARK: - Elsewhere

    /// Today's card: "3,960 of 5,400 goals · Vitamin D steadiest" (the first number bold), breaking only at the dot.
    var todayLine: String {
        let goals = RecapText.together("**\(number(recap.goalsMet))** of \(number(recap.goalsCounted)) \(GoalProgress.goals(recap.goalsCounted))")
        return recap.steadiest.map { "\(goals) · \(RecapText.together("\($0.name) steadiest"))" } ?? goals
    }

    /// History's row: "Latest: 2026 · 3,960 of 5,400 goals".
    var historyLine: String {
        "Latest: \(yearName) · \(RecapText.together("\(number(recap.goalsMet)) of \(number(recap.goalsCounted)) \(GoalProgress.goals(recap.goalsCounted))"))"
    }

    /// "Your 2026 in nutrx".
    var notificationTitle: String { "Your \(yearName) in nutrx" }

    /// "You met 73% of your goals in 2026. Vitamin D was your steadiest."
    var notificationBody: String {
        let goals = "You met \(percent)% of your goals in \(yearName)."
        return recap.steadiest.map { "\(goals) \($0.name) was your steadiest." } ?? goals
    }

    /// Set up before the year's facts are in: no numbers that could be out of date.
    var notificationBodyWithoutFacts: String { "See what you hit in \(yearName) and what slipped." }

    /// Before the first year has something in it: "Your first yearly recap arrives on 1 January".
    static func firstTitle(calendar: Calendar = .current) -> String {
        "Your first yearly recap arrives on 1 \(calendar.standaloneMonthSymbols[0])"
    }

    static func firstBody(daysLogged: Int, calendar: Calendar = .current) -> String {
        let january = calendar.standaloneMonthSymbols[0]
        switch daysLogged {
        case 0: return "Log this year and the recap on 1 \(january) will sum it up."
        case 1: return "You've logged 1 day so far. The recap on 1 \(january) will cover the whole year."
        default: return "You've logged \(daysLogged) days so far. The recap on 1 \(january) will cover the whole year."
        }
    }

    // MARK: - Pieces

    /// "May".
    func monthName(_ monthStart: Date) -> String {
        calendar.standaloneMonthSymbols[calendar.component(.month, from: monthStart) - 1]
    }

    func days(_ count: Int, _ unit: String) -> String { count == 1 ? "1 \(unit)" : "\(count) \(unit)s" }

    /// "A", "A and B", "A, B and C".
    func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// "3,960": a year's goals run into the thousands.
    func number(_ value: Int) -> String { value.formatted(.number.locale(calendar.locale ?? .current)) }

    static func percent(_ rate: Double?) -> Int { YearlyRecap.wholePercent(rate) }

    private var year: Int { calendar.component(.year, from: recap.yearStart) }

    /// Every number the year's words may use, for checking a reworded summary.
    var factNumbers: Set<Int> {
        var numbers: Set<Int> = [recap.goalsMet, recap.goalsCounted, recap.fullDays, recap.dayCount, recap.daysLogged,
                                 recap.daysElapsed, percent, year, 1, recap.started.count]
        if let best = recap.bestMonth { numbers.insert(Self.percent(best.rate)) }
        if let most = recap.mostLogged { numbers.formUnion([most.daysLogged, most.daysElapsed]) }
        if let streak = recap.longestStreak { numbers.insert(streak) }
        for goal in recap.weekly { numbers.formUnion([goal.weeksMet, goal.weeks]) }
        for nutrient in recap.nutrients {
            numbers.formUnion([nutrient.daysMet, nutrient.daysCounted, nutrient.missedDays.count,
                               nutrient.overLimitDays.count])
        }
        // Numbers inside names ("Vitamin B12", "Omega-3").
        for name in recap.nutrients.map(\.name) + recap.weekly.map(\.name) + recap.started.map(\.name) {
            numbers.formUnion(name.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
        }
        return numbers
    }
}
