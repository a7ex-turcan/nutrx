import Foundation

/// History's year grid (DESIGN.md §4.9a), GitHub's contribution grid for full days: a column per week, the calendar's
/// first weekday on top, the last column the week holding today. Days after today are left out (nil), so the last
/// column ends on today.
struct YearGrid: Equatable {
    /// A year of weeks, the most GitHub shows: 52 whole weeks before this one, and this one.
    static let defaultWeekCount = 53

    struct Week: Equatable, Identifiable {
        /// Start of the week's first day.
        let start: Date
        /// Seven days in row order; nil after today.
        let days: [Date?]
        /// "Jun" over the week holding the 1st of a month, else nil.
        let monthLabel: String?

        var id: Date { start }
    }

    /// Oldest first.
    let weeks: [Week]
    /// Start of today.
    let today: Date
    /// Short weekday names in row order, e.g. Mon … Sun for a Monday-first calendar.
    let weekdaySymbols: [String]
    /// The rows that get a weekday label, as on GitHub: Monday, Wednesday and Friday, wherever the week starts.
    let labelledRows: Set<Int>

    init(today: Date, weekCount: Int = Self.defaultWeekCount, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: today)
        self.today = today
        let offset = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        let thisWeek = calendar.date(byAdding: .day, value: -offset, to: today)!

        weeks = (0..<max(weekCount, 1)).reversed().map { back in
            let start = calendar.date(byAdding: .day, value: -7 * back, to: thisWeek)!
            let days: [Date?] = (0..<7).map { index in
                // From the week's start, not by adding 24 h, so a day the clocks change is still one day.
                let day = calendar.date(byAdding: .day, value: index, to: start).map { calendar.startOfDay(for: $0) }
                return day.flatMap { $0 <= today ? $0 : nil }
            }
            let first = days.compactMap { $0 }.first { calendar.component(.day, from: $0) == 1 }
            let label = first.map { calendar.shortStandaloneMonthSymbols[calendar.component(.month, from: $0) - 1] }
            return Week(start: start, days: days, monthLabel: label)
        }

        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }  // weekday index (0 = Sunday) per row
        weekdaySymbols = order.map { calendar.shortStandaloneWeekdaySymbols[$0] }
        labelledRows = Set(order.indices.filter { [1, 3, 5].contains(order[$0]) })
    }

    /// Every day in the grid, oldest first: today and the days before it.
    var days: [Date] { weeks.flatMap { $0.days.compactMap { $0 } } }

    /// How each of the grid's days reads in `log`, as on the calendar.
    func completions(in log: HistoryLog) -> [Date: DayCompletion] {
        Dictionary(days.map { ($0, log.day($0).completion) }, uniquingKeysWith: { first, _ in first })
    }

    /// The title's count: the full days (every goal that counted met, the streak's days) among `completions`.
    static func fullDayCount(_ completions: [Date: DayCompletion]) -> Int {
        completions.values.filter { $0 == .allMet }.count
    }
}
