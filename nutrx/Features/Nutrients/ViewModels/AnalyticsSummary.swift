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

/// Stats for the selected period (DESIGN.md §4.8): the `days` ending today, with hit rate, daily average and
/// best day over the *completed*, tracked days — today is drawn but not counted until it's over.
struct AnalyticsSummary: Equatable {
    let days: [AnalyticsDay]
    let metDays: Int
    let countedDays: Int
    let average: Double?
    let bestDay: AnalyticsDay?

    var hitRate: Double? {
        countedDays > 0 ? Double(metDays) / Double(countedDays) : nil
    }

    /// - Parameter totals: day totals keyed by start of day; missing days count as 0.
    /// - Parameter endDate: the last day of a set course (#99); days after it aren't tracked.
    init(dayCount: Int, totals: [Date: Double], goal: AnalyticsGoal, createdAt: Date, endDate: Date? = nil,
         today: Date, calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: today)
        let firstTracked = calendar.startOfDay(for: createdAt)

        days = (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { return nil }
            let total = max(0, totals[date] ?? 0)
            return AnalyticsDay(date: date, total: total, isToday: offset == 0,
                                isTracked: date >= firstTracked
                                    && NutrientCourse.includes(endDate, day: date, calendar: calendar),
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
    }
}
