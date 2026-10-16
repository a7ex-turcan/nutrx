import Foundation

/// One day of Apple Health as nutrx reads it: live, in memory, never stored or synced (nutrx Pro, phase 7).
struct HealthDay: Equatable {
    /// Minutes asleep in the night after this day (sleep that ends the next morning).
    var sleepMinutes: Double?
    /// Any workout that day.
    var workedOut: Bool = false
    /// Active energy that day, in kilocalories.
    var activeEnergy: Double?

    var hasData: Bool { sleepMinutes != nil || workedOut || activeEnergy != nil }
}

/// Minutes asleep per night from Health's sleep samples. Several sources (a Watch and a sleep app) can record the same
/// night, so overlapping intervals are merged before they're added up; a night is credited to the day before the
/// morning it ends (sleep ending before noon belongs to the previous day's night). Pure, tested in `HealthTrendsTests`.
enum SleepNights {
    static func minutes(_ intervals: [DateInterval], calendar: Calendar) -> [Date: Double] {
        var byNight: [Date: [DateInterval]] = [:]
        for interval in intervals {
            byNight[calendar.startOfDay(for: interval.end.addingTimeInterval(-12 * 3600)), default: []].append(interval)
        }
        return byNight.mapValues { intervals in
            var merged: [DateInterval] = []
            for interval in intervals.sorted(by: { $0.start < $1.start }) {
                if let last = merged.last, interval.start <= last.end {
                    merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
                } else {
                    merged.append(interval)
                }
            }
            return merged.reduce(0) { $0 + $1.duration / 60 }
        }
    }
}

/// How a nutrient lines up with Apple Health over the last four weeks (nutrx Pro, docs/pro/PLAN.md phase 7). Pure:
/// simple differences between groups of days, only with enough paired days and a difference big enough to matter.
/// It describes patterns in the user's own data and never claims a cause or advises (`HealthText`).
enum HealthTrends {
    enum State: Equatable {
        /// Not enough days with both a log and Health data yet ("9 of 14 days").
        case notEnoughData(pairedDays: Int)
        /// Apple Health has nothing for these four weeks.
        case noHealthData
        /// Enough days, no difference that stands out.
        case noPattern(checkedDays: Int)
        /// One or two findings: sleep first, then workouts (or active energy).
        case findings([Finding])
    }

    struct Finding: Equatable {
        enum Kind: Equatable {
            /// Sleep the night after days over the threshold vs other days.
            case sleep
            /// Intake on workout days vs rest days.
            case workouts
            /// Intake on more active days (above the median active energy) vs less active ones.
            case activeEnergy
        }

        let kind: Kind
        /// The first group: days over the threshold, workout days, more active days.
        let first: Group
        /// The second: other days, rest days, less active days.
        let second: Group
        /// Sleep findings: the intake that splits the days (300 mg of a 400 mg limit, or the goal).
        let threshold: Double?

        struct Group: Equatable {
            /// Average minutes asleep (sleep) or average intake (workouts, active energy).
            let average: Double
            let days: Int
        }

        var difference: Double { first.average - second.average }
    }

    static let windowDays = 28
    static let minimumPairedDays = 14
    static let minimumGroupDays = 4
    /// A difference in intake has to be at least this share of the average intake.
    static let minimumIntakeShare = 0.15
    static let minimumSleepMinutes = 20.0

    /// - Parameters:
    ///   - totals: the nutrient's totals per day (start of day); a missing day is 0.
    ///   - loggedDays: days with anything logged in nutrx, so a day the app wasn't used doesn't read as 0.
    ///   - health: Apple Health per day (start of day).
    static func state(totals: [Date: Double], loggedDays: Set<Date>, health: [Date: HealthDay], goal: AnalyticsGoal,
                      createdAt: Date, today: Date, calendar: Calendar = .current) -> State {
        let startOfToday = calendar.startOfDay(for: today)
        let firstTracked = calendar.startOfDay(for: createdAt)
        let window = (1...windowDays).compactMap { calendar.date(byAdding: .day, value: -$0, to: startOfToday) }
        guard window.contains(where: { health[$0]?.hasData == true }) else { return .noHealthData }

        let paired = window.filter { day in
            day >= firstTracked && loggedDays.contains(day) && health[day]?.hasData == true
        }
        guard paired.count >= minimumPairedDays else { return .notEnoughData(pairedDays: paired.count) }

        let intake: (Date) -> Double = { max(0, totals[$0] ?? 0) }
        let averageIntake = paired.map(intake).reduce(0, +) / Double(paired.count)
        var findings: [Finding] = []

        // Sleep the night after: days over the threshold vs the rest.
        let threshold = sleepThreshold(goal)
        let withSleep = paired.filter { health[$0]?.sleepMinutes != nil }
        let over = withSleep.filter { isOver(intake($0), threshold: threshold, goal: goal) }
        let others = withSleep.filter { !isOver(intake($0), threshold: threshold, goal: goal) }
        if over.count >= minimumGroupDays, others.count >= minimumGroupDays {
            let sleep: ([Date]) -> Double = { days in days.compactMap { health[$0]?.sleepMinutes }.reduce(0, +) / Double(days.count) }
            let finding = Finding(kind: .sleep, first: .init(average: sleep(over), days: over.count),
                                  second: .init(average: sleep(others), days: others.count), threshold: threshold)
            if abs(finding.difference) >= minimumSleepMinutes { findings.append(finding) }
        }

        // Intake on workout days vs rest days; failing that, more vs less active days.
        func intakeFinding(_ kind: Finding.Kind, _ first: [Date], _ second: [Date]) -> Finding? {
            guard first.count >= minimumGroupDays, second.count >= minimumGroupDays, averageIntake > 0 else { return nil }
            let average: ([Date]) -> Double = { days in days.map(intake).reduce(0, +) / Double(days.count) }
            let finding = Finding(kind: kind, first: .init(average: average(first), days: first.count),
                                  second: .init(average: average(second), days: second.count), threshold: nil)
            return abs(finding.difference) >= averageIntake * minimumIntakeShare ? finding : nil
        }
        let workoutDays = paired.filter { health[$0]?.workedOut == true }
        let restDays = paired.filter { health[$0]?.workedOut != true }
        if let workouts = intakeFinding(.workouts, workoutDays, restDays) {
            findings.append(workouts)
        } else {
            let withEnergy = paired.filter { health[$0]?.activeEnergy != nil }
            let energies = withEnergy.compactMap { health[$0]?.activeEnergy }.sorted()
            if !energies.isEmpty {
                let median = energies[energies.count / 2]
                let active = withEnergy.filter { (health[$0]?.activeEnergy ?? 0) >= median }
                let lessActive = withEnergy.filter { (health[$0]?.activeEnergy ?? 0) < median }
                if let energy = intakeFinding(.activeEnergy, active, lessActive) { findings.append(energy) }
            }
        }

        return findings.isEmpty ? .noPattern(checkedDays: paired.count) : .findings(findings)
    }

    /// The intake that splits days for the sleep comparison: three quarters of an "at most" limit (nearing it), the
    /// goal for "at least", the minimum of a range.
    static func sleepThreshold(_ goal: AnalyticsGoal) -> Double {
        goal.goalType == .maximum ? goal.target * 0.75 : goal.target
    }

    /// Over the threshold: past three quarters of an "at most" limit, or the goal met (`GoalProgress`, so a day above
    /// a range's maximum isn't "goal met").
    private static func isOver(_ total: Double, threshold: Double, goal: AnalyticsGoal) -> Bool {
        goal.goalType == .maximum ? total > threshold : goal.isMet(total)
    }
}
