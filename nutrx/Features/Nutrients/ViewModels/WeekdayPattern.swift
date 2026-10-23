import Foundation

/// Hit rate per weekday over the last four weeks of completed days (DESIGN.md §4.8 heatmap).
struct WeekdayPattern: Equatable {
    struct Entry: Identifiable, Equatable {
        /// `Calendar` weekday, 1 = Sunday … 7 = Saturday.
        let weekday: Int
        /// nil when no tracked day of this weekday falls in the window.
        let hitRate: Double?

        var id: Int { weekday }
    }

    /// One entry per weekday, starting at the calendar's first weekday.
    let entries: [Entry]
    /// The weekday to call out — the single weakest one, if it's at least 25 points below the average and
    /// every rated weekday has been seen at least twice (so one bad day isn't a "pattern").
    let weakestWeekday: Int?

    static let windowDays = 28
    /// How far below the average the weakest weekday has to be before we mention it.
    static let insightGap = 0.25
    /// Days of each rated weekday needed before we mention a weakest one.
    static let insightMinimumDays = 2

    /// Off days (schedules, #132) aren't rated, so a weekday with no dose days has no rate and its square is blank.
    init(totals: [Date: Double], goal: AnalyticsGoal, createdAt: Date, endDate: Date? = nil,
         courseGaps: [ClosedRange<Date>] = [], schedule: NutrientSchedule = NutrientSchedule(), today: Date,
         calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: today)
        let firstTracked = calendar.startOfDay(for: createdAt)

        var met: [Int: Int] = [:]
        var counted: [Int: Int] = [:]
        for offset in 1...Self.windowDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                  date >= firstTracked, NutrientCourse.includes(endDate, gaps: courseGaps, day: date, calendar: calendar),
                  schedule.isCountedDay(date, calendar: calendar)
            else { continue }
            let weekday = calendar.component(.weekday, from: date)
            counted[weekday, default: 0] += 1
            if goal.isMet(max(0, totals[date] ?? 0)) { met[weekday, default: 0] += 1 }
        }

        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        entries = order.map { weekday in
            let days = counted[weekday, default: 0]
            return Entry(weekday: weekday, hitRate: days > 0 ? Double(met[weekday, default: 0]) / Double(days) : nil)
        }

        let rated = entries.compactMap { entry in entry.hitRate.map { (entry.weekday, $0) } }
        let enoughDays = counted.values.allSatisfy { $0 >= Self.insightMinimumDays }
        if rated.count > 1, enoughDays, let weakest = rated.min(by: { $0.1 < $1.1 }),
           rated.filter({ $0.1 == weakest.1 }).count == 1 {
            let average = rated.reduce(0) { $0 + $1.1 } / Double(rated.count)
            weakestWeekday = average - weakest.1 >= Self.insightGap - 1e-9 ? weakest.0 : nil
        } else {
            weakestWeekday = nil
        }
    }

    /// Heatmap fill strength for a hit rate: 100% → full tint, ≥ 75% → 70%, ≥ 50% → 40%, otherwise 15%.
    static func fillOpacity(for hitRate: Double?) -> Double {
        guard let hitRate else { return 0.15 }
        switch hitRate {
        case 0.9999...: return 1
        case 0.75...: return 0.7
        case 0.5...: return 0.4
        default: return 0.15
        }
    }
}
