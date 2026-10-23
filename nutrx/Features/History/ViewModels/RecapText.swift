import Foundation

/// The weekly recap's words (docs/pro/design/5-weekly-recap), from `WeeklyRecap`'s facts only. The template summary
/// runs everywhere; with Apple Intelligence `RecapPhrasing` may reword it, checked against these facts. It describes
/// and never advises: no "try", no "should", no amounts to aim for.
struct RecapText {
    let recap: WeeklyRecap
    let calendar: Calendar

    init(_ recap: WeeklyRecap, calendar: Calendar = .current) {
        self.recap = recap
        self.calendar = calendar
    }

    // MARK: - Hero

    /// "5 – 11 October", or "28 September – 4 October" across a month (en dash, spaced).
    var range: String {
        let sunday = calendar.date(byAdding: .day, value: 6, to: recap.weekStart)!
        let sameMonth = calendar.component(.month, from: recap.weekStart) == calendar.component(.month, from: sunday)
        let start = sameMonth ? "\(calendar.component(.day, from: recap.weekStart))" : dayMonth(recap.weekStart)
        return "\(start) – \(dayMonth(sunday))"
    }

    /// "31 of 42 goals met".
    var headline: String { "\(recap.goalsMet) of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted)) met" }

    /// The ring's centre: "5/7" over "full days"; out of fewer days when some were rest days (schedules, #132).
    var ringValue: String { "\(recap.fullDays)/\(recap.dayCount)" }
    let ringLabel = "full days"

    /// Three or four sentences: steadiest, slipped, over a limit, streak.
    var summary: String {
        var sentences: [String] = []
        let everyDay = recap.nutrients.filter { $0.daysMet == $0.daysCounted }
        if recap.goalsCounted > 0, recap.goalsMet == recap.goalsCounted {
            // Every counted day with goals was a full day.
            switch recap.fullDays {
            case 1: sentences.append("You met every goal on the one day counted.")
            case 2: sentences.append("You met every goal on both days.")
            default: sentences.append("You met every goal on all \(recap.fullDays) days.")
            }
        } else if everyDay.count > 3, let steadiest = recap.steadiest {
            sentences.append("You hit \(everyDay.count) goals every day, including \(steadiest.name).")
        } else if everyDay.count > 1 {
            sentences.append("You hit \(list(everyDay.map(\.name))) every day.")
        } else if let steadiest = recap.steadiest {
            sentences.append("You hit \(steadiest.name) \(steadiest.daysMet) of \(steadiest.daysCounted) days.")
        } else {
            sentences.append("No goals were met this week.")
        }
        let over = recap.overLimit
        if let slipped = recap.slipped, slipped.id != over?.id {
            sentences.append("\(slipped.name) slipped \(when(slipped.missedDays)).")
        }
        if let over {
            let limit = over.goalType == .range ? "its range" : "your limit"
            sentences.append("\(over.name) went over \(limit) \(when(over.overLimitDays)).")
        }
        // Times a week (#132): judged by the week, not day by day.
        for goal in recap.weekly {
            sentences.append("\(goal.name): \(goal.met) of \(goal.times) \(recap.isWeekOver ? "this week" : "so far this week").")
        }
        if let streak = recap.streak, streak.now > 0 {
            sentences.append("Your streak stood at \(days(streak.now)).")
        }
        return sentences.joined(separator: " ")
    }

    // MARK: - Fact cards

    struct Card: Equatable {
        enum Kind { case steadiest, slipped, weekday, streak }
        let kind: Kind
        let label: String
        let value: String
        let detail: String
        /// The nutrient whose tint and symbol the card shows, if any.
        let nutrientID: UUID?
    }

    /// Steadiest, Slipped, Day you tend to miss, Streak — whichever have something to say.
    var cards: [Card] {
        var cards: [Card] = []
        if let steadiest = recap.steadiest {
            cards.append(Card(kind: .steadiest, label: "Steadiest", value: steadiest.name,
                              detail: "\(steadiest.daysMet) of \(steadiest.daysCounted) days", nutrientID: steadiest.id))
        }
        if let slipped = recap.slipped {
            cards.append(Card(kind: .slipped, label: "Slipped", value: slipped.name,
                              detail: "Missed \(dayList(slipped.missedDays, short: true))", nutrientID: slipped.id))
        }
        if let miss = recap.weakestWeekday {
            cards.append(Card(kind: .weekday, label: "Day you tend to miss", value: weekdayName(miss.weekday),
                              detail: "\(miss.missed) of the last \(miss.weeks) weeks", nutrientID: nil))
        }
        if let streak = recap.streak {
            cards.append(Card(kind: .streak, label: "Streak", value: days(streak.now),
                              detail: streakDetail(streak), nutrientID: nil))
        }
        return cards
    }

    func streakDetail(_ streak: WeeklyRecap.StreakChange) -> String {
        if streak.now == streak.previous { return "Same as last Sunday" }
        if streak.previous == 0 { return "Started this week" }
        if streak.now == 0 { return "Ended this week, after \(days(streak.previous))" }
        return streak.now > streak.previous ? "Up from \(streak.previous) last Sunday"
            : "Down from \(streak.previous) last Sunday"
    }

    // MARK: - Elsewhere

    /// Today's card: "31 of 42 goals · Vitamin D steadiest" (the first number bold). Each part keeps together
    /// (no-break spaces), so a narrow line breaks at the dot, never inside "Vitamin D".
    var todayLine: String {
        let goals = Self.together("**\(recap.goalsMet)** of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted))")
        return recap.steadiest.map { "\(goals) · \(Self.together("\($0.name) steadiest"))" } ?? goals
    }

    /// History's row: "Latest: 5 – 11 October · 31 of 42 goals", breaking only between the parts.
    var historyLine: String {
        "Latest: \(Self.together(range)) · \(Self.together("\(recap.goalsMet) of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted))"))"
    }

    /// No-break spaces, and word joiners around a dash (a line may otherwise break after "5 –"), so the phrase
    /// wraps as one piece.
    static func together(_ phrase: String) -> String {
        phrase.replacingOccurrences(of: " ", with: "\u{00A0}")
            .replacingOccurrences(of: "–", with: "\u{2060}–\u{2060}")
    }

    static let notificationTitle = "Your week in nutrx"

    /// "You hit 31 of 42 goals. Vitamin D was your steadiest."
    var notificationBody: String {
        let goals = "You hit \(recap.goalsMet) of \(recap.goalsCounted) \(GoalProgress.goals(recap.goalsCounted))."
        return recap.steadiest.map { "\(goals) \($0.name) was your steadiest." } ?? goals
    }

    /// When the notification is set up before the week's facts are in: no numbers that could be out of date.
    static let notificationBodyWithoutFacts = "See what you hit this week and what slipped."

    /// The first-week hero: "Your first recap arrives Sunday".
    static let firstTitle = "Your first recap arrives Sunday"

    static func firstBody(daysLogged: Int) -> String {
        switch daysLogged {
        case 0: "Log this week and Sunday's recap will sum it up."
        case 1: "You've logged 1 day so far. Sunday's recap will cover the whole week."
        default: "You've logged \(daysLogged) days so far. Sunday's recap will cover the whole week."
        }
    }

    static func explainer(device: String) -> String {
        "Each Sunday evening, nutrx sums up your week from your own logs — what you hit, what slipped and which day. "
            + "It's written on your \(device) and never leaves it."
    }

    // MARK: - Pieces

    /// "on the weekend", "on Monday", "on Tuesday and Thursday", "on 4 days".
    func when(_ dates: [Date]) -> String {
        let weekdays = Set(dates.map { calendar.component(.weekday, from: $0) })
        if weekdays == [1, 7] { return "on the weekend" }
        return dates.count > 3 ? "on \(dates.count) days" : "on \(dayList(dates, short: false))"
    }

    /// "Sat and Sun" / "Saturday and Sunday", "Mon, Wed and Fri"; four or more: "4 days".
    func dayList(_ dates: [Date], short: Bool) -> String {
        guard dates.count <= 3 else { return "\(dates.count) days" }
        let names = dates.map { date in
            let index = calendar.component(.weekday, from: date) - 1
            return short ? calendar.shortWeekdaySymbols[index] : calendar.weekdaySymbols[index]
        }
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// "A", "A and B", "A, B and C".
    func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    func weekdayName(_ weekday: Int) -> String { calendar.weekdaySymbols[weekday - 1] }

    func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }

    private func dayMonth(_ date: Date) -> String {
        "\(calendar.component(.day, from: date)) \(calendar.standaloneMonthSymbols[calendar.component(.month, from: date) - 1])"
    }

    /// Every number the recap's words may use, for checking a reworded summary.
    var factNumbers: Set<Int> {
        var numbers: Set<Int> = [recap.goalsMet, recap.goalsCounted, recap.fullDays, recap.daysLogged, 7,
                                 recap.dayCount]
        numbers.insert(recap.nutrients.filter { $0.daysMet == $0.daysCounted }.count)
        for goal in recap.weekly { numbers.formUnion([goal.met, goal.times]) }
        for week in recap.nutrients {
            numbers.formUnion([week.daysMet, week.daysCounted, week.missedDays.count, week.overLimitDays.count])
        }
        if let streak = recap.streak { numbers.formUnion([streak.now, streak.previous]) }
        if let miss = recap.weakestWeekday { numbers.formUnion([miss.missed, miss.weeks]) }
        // Numbers inside names ("Vitamin B12", "Omega-3").
        for week in recap.nutrients {
            numbers.formUnion(week.name.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
        }
        return numbers
    }
}
