import Foundation

/// How a nutrient lines up with How you feel's answers over the last four weeks (nutrx Pro, #133,
/// docs/pro/HOW-YOU-FEEL.md §3). Pure, like `HealthTrends`: the days the goal was met (or an "at most" limit neared)
/// against the other days, per question, only with enough answered days and a difference big enough to matter. It
/// describes patterns in the user's own answers and never claims a cause or advises (`FeelingTrendText`).
enum FeelingTrends {
    enum State: Equatable {
        /// No question has 14 paired days yet; the one closest to it ("Sleep last night: 9 of 14 days").
        case notEnoughData(question: String, pairedDays: Int)
        /// Questions with enough days, and no difference that stands out (the most days checked).
        case noPattern(checkedDays: Int)
        /// One or two findings, the largest first.
        case findings([Finding])
    }

    /// A question as the trends read it: its answers by day (start of day), keyed by the day they're about.
    struct Question: Equatable {
        let title: String
        let kind: FeelingKind
        let preset: FeelingPreset?
        /// Sleep: the answer on day D is about the night after D − 1, so it pairs with D − 1 (§1).
        let aboutNightBefore: Bool
        /// Answers by the day they were given.
        let answers: [Date: Int]
    }

    struct Finding: Equatable {
        let question: Question
        /// Days over the threshold: the goal met, or past three quarters of an "at most" limit.
        let first: Group
        /// The other days.
        let second: Group
        /// An "at most" nutrient's amount that splits the days (300 mg of 400); nil when it's the goal met.
        let threshold: Double?

        struct Group: Equatable {
            /// The average answer (1–5), or the share of yes days (0–1).
            let average: Double
            let days: Int
            /// Yes / no: the days answered yes.
            let yesDays: Int
        }

        var difference: Double { first.average - second.average }

        /// How big it is, comparable across kinds: a scale's gap out of 4, a yes share's gap.
        var size: Double { question.kind == .scale ? abs(difference) / 4 : abs(difference) }
    }

    static let windowDays = 28
    static let minimumPairedDays = 14
    static let minimumGroupDays = 4
    static let minimumScaleGap = 0.5
    static let minimumYesShareGap = 0.25
    static let maximumFindings = 2

    /// - Parameters:
    ///   - totals: the nutrient's totals per day (start of day); a missing day is 0.
    ///   - loggedDays: days with anything logged in nutrx, so a day the app wasn't used doesn't read as 0.
    ///   - questions: How you feel's questions on the card; none gives nil.
    ///   - counts: whether the nutrient counts on a day (tracked, due under its schedule, its course running).
    static func state(totals: [Date: Double], loggedDays: Set<Date>, questions: [Question], goal: AnalyticsGoal,
                      counts: (Date) -> Bool, today: Date, calendar: Calendar = .current) -> State? {
        guard !questions.isEmpty else { return nil }
        let startOfToday = calendar.startOfDay(for: today)
        let window = (1...windowDays).compactMap { calendar.date(byAdding: .day, value: -$0, to: startOfToday) }
        let days = window.filter { counts($0) && loggedDays.contains($0) }
        let threshold = HealthTrends.sleepThreshold(goal, on: startOfToday)
        let isOver: (Date) -> Bool = { day in
            let total = max(0, totals[day] ?? 0)
            return goal.goalType == .maximum ? total > threshold : goal.isMet(total, on: day)
        }

        var findings: [Finding] = []
        var readyDays: [Int] = []
        var gathering: (question: String, days: Int)?
        for question in questions {
            let answered = days.compactMap { day in answer(question, about: day, calendar: calendar).map { (day, $0) } }
            guard answered.count >= minimumPairedDays else {
                if answered.count > (gathering?.days ?? -1) { gathering = (question.title, answered.count) }
                continue
            }
            readyDays.append(answered.count)
            let over = answered.filter { isOver($0.0) }.map(\.1)
            let others = answered.filter { !isOver($0.0) }.map(\.1)
            guard over.count >= minimumGroupDays, others.count >= minimumGroupDays else { continue }
            let finding = Finding(question: question, first: group(over, kind: question.kind),
                                  second: group(others, kind: question.kind),
                                  threshold: goal.goalType == .maximum ? threshold : nil)
            let gap = question.kind == .scale ? minimumScaleGap : minimumYesShareGap
            if abs(finding.difference) >= gap { findings.append(finding) }
        }

        if !findings.isEmpty {
            return .findings(Array(findings.sorted { $0.size > $1.size }.prefix(maximumFindings)))
        }
        if let checked = readyDays.max() { return .noPattern(checkedDays: checked) }
        return .notEnoughData(question: gathering?.question ?? questions[0].title, pairedDays: gathering?.days ?? 0)
    }

    /// The answer about `day`: given that day, or for a question about the night before, the next day.
    static func answer(_ question: Question, about day: Date, calendar: Calendar = .current) -> Int? {
        let asked = question.aboutNightBefore ? calendar.date(byAdding: .day, value: 1, to: day)! : day
        return question.answers[calendar.startOfDay(for: asked)]
    }

    private static func group(_ values: [Int], kind: FeelingKind) -> Finding.Group {
        let yes = values.filter { $0 == 1 }.count
        let average = kind == .scale ? Double(values.reduce(0, +)) / Double(values.count)
                                     : Double(yes) / Double(values.count)
        return Finding.Group(average: average, days: values.count, yesDays: kind == .yesNo ? yes : 0)
    }
}

extension FeelingTrends.Question {
    /// The words under 1 and 5, as `FeelingQuestion.ends`.
    var ends: (low: String, high: String) { preset?.ends ?? FeelingPreset.ownEnds }

    /// From the store: the newest answer per day.
    init(_ question: FeelingQuestion, calendar: Calendar = .current) {
        var answers: [Date: (value: Int, updatedAt: Date)] = [:]
        for answer in question.answers ?? [] {
            let day = calendar.startOfDay(for: answer.day)
            if let kept = answers[day], kept.updatedAt >= answer.updatedAt { continue }
            answers[day] = (answer.value, answer.updatedAt)
        }
        self.init(title: question.displayTitle, kind: question.kind, preset: question.preset,
                  aboutNightBefore: question.preset?.isAboutNightBefore ?? false,
                  answers: answers.mapValues(\.value))
    }
}
