import Foundation

/// One day of a nutrient's history on the analytics screen.
struct AnalyticsDay: Identifiable, Equatable {
    /// Start of the day.
    let date: Date
    /// The day's total, floored at 0.
    let total: Double
    let isToday: Bool
    /// On or after the day the nutrient was created — earlier days don't count toward any stat.
    let isTracked: Bool
    let countsAsMet: Bool

    var id: Date { date }
}

/// The goal a day is judged against.
struct AnalyticsGoal: Equatable {
    let goalType: GoalType
    let target: Double
    let upperBound: Double?

    func isMet(_ total: Double) -> Bool {
        GoalProgress(current: total, goalType: goalType, target: target, upperBound: upperBound).countsAsMet
    }
}

extension AnalyticsGoal {
    init(nutrient: Nutrient) {
        self.init(goalType: nutrient.goalType, target: nutrient.dailyTarget, upperBound: nutrient.upperBound)
    }
}

/// Under a weekly schedule (#132): the weeks that ended in the period and were wholly under it, and how many reached
/// their count.
struct AnalyticsWeeks: Equatable {
    let met: Int
    let total: Int
}

/// Stats for the selected period (DESIGN.md §4.8): the `days` ending today, with hit rate, daily average and
/// best day over the *completed*, tracked days — today is drawn but not counted until it's over.
struct AnalyticsSummary: Equatable {
    let days: [AnalyticsDay]
    let metDays: Int
    let countedDays: Int
    let average: Double?
    let bestDay: AnalyticsDay?
    /// Set when a weekly schedule (#132) is in effect today: the hit rate is then by weeks, not days.
    var weeks: AnalyticsWeeks? = nil

    var hitRate: Double? {
        if let weeks { return weeks.total > 0 ? Double(weeks.met) / Double(weeks.total) : nil }
        return countedDays > 0 ? Double(metDays) / Double(countedDays) : nil
    }

    /// - Parameter totals: day totals keyed by start of day; missing days count as 0.
    /// - Parameters:
    ///   - endDate: the last day of a set course (#99); days after it aren't tracked.
    ///   - courseGaps: days between a course's end and its restart; not tracked either.
    ///   - schedule: which days it's due (#132); off days aren't tracked.
    init(dayCount: Int, totals: [Date: Double], goal: AnalyticsGoal, createdAt: Date, endDate: Date? = nil,
         courseGaps: [ClosedRange<Date>] = [], schedule: NutrientSchedule = NutrientSchedule(), today: Date,
         calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: today)
        let firstTracked = calendar.startOfDay(for: createdAt)
        func covered(_ date: Date) -> Bool {
            date >= firstTracked && NutrientCourse.includes(endDate, gaps: courseGaps, day: date, calendar: calendar)
        }
        // A weekly schedule's days count once met, among their week's first few: from every day loaded, so a week
        // that began before the period counts its first days right.
        let weeklyCounted = schedule.hasWeekly
            ? schedule.weeklyCountedDays(totals.compactMap { day, total in
                covered(day) && goal.isMet(max(0, total)) ? day : nil
            }, calendar: calendar)
            : []

        days = (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { return nil }
            let total = max(0, totals[date] ?? 0)
            return AnalyticsDay(date: date, total: total, isToday: offset == 0,
                                isTracked: covered(date)
                                    && (schedule.isCountedDay(date, calendar: calendar)
                                        || weeklyCounted.contains(date)),
                                countsAsMet: goal.isMet(total))
        }

        let counted = days.filter { $0.isTracked && !$0.isToday }
        countedDays = counted.count
        metDays = counted.filter(\.countsAsMet).count
        average = counted.isEmpty ? nil : counted.reduce(0) { $0 + $1.total } / Double(counted.count)
        // Highest intake; the earliest day wins a tie. Nothing logged at all → no best day.
        bestDay = counted.filter { $0.total > 0 }.max { lhs, rhs in
            lhs.total == rhs.total ? lhs.date > rhs.date : lhs.total < rhs.total
        }

        guard schedule.weeklyTimes(on: startOfToday, calendar: calendar) != nil,
              let firstDay = days.first?.date else { return }
        // The weeks that ended in the period (their Sunday in it, before today), judged only when wholly under the
        // weekly schedule and the nutrient's course.
        var met = 0
        var total = 0
        var monday = NutrientSchedule.weekStart(of: firstDay, calendar: calendar)
        while let sunday = calendar.date(byAdding: .day, value: 6, to: monday), sunday < startOfToday {
            let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
            if sunday >= firstDay, week.allSatisfy(covered),
               schedule.isWholeWeekly(weekStarting: monday, calendar: calendar),
               let times = schedule.weeklyTimes(on: monday, calendar: calendar) {
                total += 1
                if week.filter(weeklyCounted.contains).count >= times { met += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: monday) else { break }
            monday = next
        }
        weeks = AnalyticsWeeks(met: met, total: total)
    }
}
