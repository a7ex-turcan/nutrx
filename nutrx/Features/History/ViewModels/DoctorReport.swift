import Foundation

/// What the report for your doctor says about a period (nutrx Pro, docs/pro/PLAN.md phase 8). Pure: built from a
/// `HistoryLog`, so a goal counts on a day exactly as in History and for streaks. Only days with something logged
/// in nutrx count toward hit rates and averages: a day nothing was logged is unknown, not a missed goal.
struct DoctorReport: Equatable {
    struct Day: Equatable {
        let date: Date
        /// The day's total, floored at 0; nil when the day doesn't count (not logged, or before the nutrient).
        let total: Double?
        let isMet: Bool
        /// That day's goal, a dose plan's step then (#135).
        var goal: NutrientGoal? = nil
    }

    /// Days in a row with the same goal, by index into a section's `days`.
    struct GoalRun: Equatable {
        let goal: NutrientGoal
        let first: Int
        let last: Int
    }

    struct Section: Equatable {
        let id: UUID
        let name: String
        let unit: String
        let goalType: GoalType
        /// The goal on the period's last day; each day has its own in `days` (a dose plan, #135).
        let target: Double
        let upperBound: Double?
        /// Every day of the period, oldest first.
        let days: [Day]
        let countedDays: Int
        let metDays: Int
        /// Days with an entry for this nutrient.
        let daysLogged: Int
        let average: Double?
        /// Apple Health trend sentences, when the report includes them.
        var trends: [String] = []

        /// Under a weekly schedule (#132): the whole weeks in the period and how many reached their count. The section
        /// then shows "Weeks met" instead of a day-by-day hit rate, which would always read 100 %.
        var weeks: AnalyticsWeeks? = nil
        /// That schedule's count: the goal reads "…, 3 times a week" (#248).
        var weeklyTimes: Int? = nil

        var hitRate: Double? {
            if let weeks { return weeks.total > 0 ? Double(weeks.met) / Double(weeks.total) : nil }
            return countedDays > 0 ? Double(metDays) / Double(countedDays) : nil
        }

        /// The goal's runs over the period, oldest first: one for a steady goal, one per dose plan step (#135).
        var goalRuns: [GoalRun] {
            var runs: [GoalRun] = []
            for (index, day) in days.enumerated() {
                let goal = day.goal ?? NutrientGoal(target: target, upperBound: upperBound)
                if let run = runs.last, run.goal == goal {
                    runs[runs.count - 1] = GoalRun(goal: goal, first: run.first, last: index)
                } else {
                    runs.append(GoalRun(goal: goal, first: index, last: index))
                }
            }
            return runs
        }

        /// The goal changed in the period: the section lists the steps.
        var hasSteps: Bool { goalRuns.count > 1 }
    }

    struct Note: Equatable {
        let date: Date
        let nutrientName: String
        let text: String
    }

    /// A How you feel question over the period (#133, docs/pro/HOW-YOU-FEEL.md §3), from the user's own answers.
    struct Feeling: Equatable {
        let title: String
        let kind: FeelingKind
        /// A scale's average; a yes / no question reads `yesDays`.
        let average: Double
        let yesDays: Int
        let answeredDays: Int
        /// The words under 1 and 5 ("Poor", "Great"), so a doctor can tell which way the scale runs.
        let lowWord: String
        let highWord: String
    }

    /// First and last day of the period (start of day), both included.
    let start: Date
    let end: Date
    let name: String?
    let sections: [Section]
    let notes: [Note]
    /// Days in the period with anything logged.
    let daysWithEntries: Int
    /// Goals met over goals counted, every nutrient, every logged day.
    let overallHitRate: Double?
    /// The longest run of logged days in the period with every included goal met.
    let longestStreak: Int
    /// Every day of the period, oldest first (empty when the period is).
    let days: [Date]
    /// How you felt (#133), when the report includes it: each question answered in the period.
    var feelings: [Feeling] = []
    /// How you feel's patterns for the included nutrients over the 28 days up to the period's last day, in words.
    var feelingPatterns: [String] = []

    var dayCount: Int { days.count }

    // MARK: - Building

    struct NoteEntry: Equatable {
        let date: Date
        let nutrientID: UUID
        let text: String
    }

    /// - Parameters:
    ///   - start, end: the period; `end` is clamped to yesterday (today isn't over).
    ///   - nutrientIDs: the nutrients to include, in display order; nil is every nutrient that counts in the period.
    ///   - names / units: by nutrient id.
    ///   - notes: entries' notes in the period (already trimmed and non-empty); only those for included nutrients stay.
    static func build(log: HistoryLog, names: [UUID: String], units: [UUID: String], start: Date, end: Date,
                      nutrientIDs: [UUID]? = nil, personName: String? = nil, notes: [NoteEntry] = []) -> DoctorReport {
        let calendar = log.calendar
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let first = calendar.startOfDay(for: start)
        let last = min(calendar.startOfDay(for: end), yesterday)
        var dates: [Date] = []
        var day = first
        while day <= last {
            dates.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let results = dates.map(log.day)
        let logged = results.filter(\.hasEntries)

        let included = nutrientIDs ?? log.nutrients.map(\.id).filter { id in results.contains { $0.goals.contains { $0.nutrientID == id } } }
        let byID = Dictionary(log.nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let sections = included.compactMap { id -> Section? in
            guard let nutrient = byID[id] else { return nil }
            var days: [Day] = []
            var counted = 0, met = 0, daysLogged = 0, sum = 0.0
            for result in results {
                let goal = result.goals.first { $0.nutrientID == id }
                // Before the nutrient was added, its first day's goal (as in analytics).
                let dayGoal = nutrient.goal(on: max(result.date, calendar.startOfDay(for: nutrient.createdAt)),
                                            calendar: calendar)
                if log.loggedNutrients(on: result.date).contains(id) { daysLogged += 1 }
                guard let goal, result.hasEntries else {
                    days.append(Day(date: result.date, total: nil, isMet: false, goal: dayGoal))
                    continue
                }
                counted += 1
                sum += goal.total
                if goal.isMet { met += 1 }
                days.append(Day(date: result.date, total: goal.total, isMet: goal.isMet, goal: dayGoal))
            }
            let lastGoal = nutrient.goal(on: last, calendar: calendar)
            var section = Section(id: id, name: names[id] ?? "", unit: units[id] ?? "", goalType: nutrient.goalType,
                                  target: lastGoal.target, upperBound: lastGoal.upperBound, days: days,
                                  countedDays: counted, metDays: met, daysLogged: daysLogged,
                                  average: counted > 0 ? sum / Double(counted) : nil)
            if let times = nutrient.schedule.weeklyTimes(on: last, calendar: calendar) {
                section.weeks = weeks(of: id, from: first, through: last, log: log)
                section.weeklyTimes = times
            }
            return section
        }

        let counted = sections.reduce(0) { $0 + $1.countedDays }
        let met = sections.reduce(0) { $0 + $1.metDays }
        // A full day for this report: logged, and every included goal that counts that day met (a nutrient left out of
        // the report doesn't break its streak).
        let includedSet = Set(included)
        var longest = 0, run = 0
        for result in results {
            let goals = result.goals.filter { includedSet.contains($0.nutrientID) }
            // No included goal counted that day (a rest day, a weekly one's off day, #132): neither breaks nor extends
            // the run.
            if goals.isEmpty { continue }
            if result.hasEntries, goals.allSatisfy(\.isMet) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        let reportNotes = notes
            .filter { includedSet.contains($0.nutrientID) && $0.date >= first && calendar.startOfDay(for: $0.date) <= last }
            .sorted { $0.date < $1.date }
            .map { Note(date: $0.date, nutrientName: names[$0.nutrientID] ?? "", text: $0.text) }

        let trimmedName = personName?.trimmingCharacters(in: .whitespaces)
        return DoctorReport(start: first, end: last, name: trimmedName?.isEmpty == false ? trimmedName : nil,
                            sections: sections, notes: reportNotes, daysWithEntries: logged.count,
                            overallHitRate: counted > 0 ? Double(met) / Double(counted) : nil,
                            longestStreak: longest, days: dates)
    }

    /// Each question's answers from `start` through `end` (both start of day), in the questions' order; one without an
    /// answer then is left out. Removed questions count too: their answers are still the user's.
    static func feelings(_ questions: [FeelingTrends.Question], start: Date, end: Date) -> [Feeling] {
        questions.compactMap { question -> Feeling? in
            let values = question.answers.filter { $0.key >= start && $0.key <= end }.map(\.value)
            guard !values.isEmpty else { return nil }
            let yes = values.filter { $0 == 1 }.count
            let average = question.kind == .scale ? Double(values.reduce(0, +)) / Double(values.count)
                                                  : Double(yes) / Double(values.count)
            let ends = question.preset?.ends ?? (low: "Low", high: "High")
            return Feeling(title: question.title, kind: question.kind, average: average,
                           yesDays: question.kind == .yesNo ? yes : 0, answeredDays: values.count,
                           lowWord: ends.low, highWord: ends.high)
        }
    }

    /// The last `days` completed days: "Last 30 days" ends yesterday.
    static func lastDays(_ days: Int, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let start = calendar.date(byAdding: .day, value: -days, to: startOfToday)!
        return (start, end)
    }
}

extension DoctorReport {
    /// A weekly nutrient's whole weeks in the period (Monday to Sunday, both inside it), judged as in analytics.
    static func weeks(of nutrientID: UUID, from first: Date, through last: Date, log: HistoryLog) -> AnalyticsWeeks {
        let calendar = log.calendar
        var monday = NutrientSchedule.weekStart(of: first, calendar: calendar)
        if monday < first, let next = calendar.date(byAdding: .day, value: 7, to: monday) { monday = next }
        var met = 0
        var total = 0
        while let sunday = calendar.date(byAdding: .day, value: 6, to: monday), sunday <= last {
            if let result = log.weekResult(of: nutrientID, weekStarting: monday) {
                total += 1
                if result.isDone { met += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: monday) else { break }
            monday = next
        }
        return AnalyticsWeeks(met: met, total: total)
    }
}
