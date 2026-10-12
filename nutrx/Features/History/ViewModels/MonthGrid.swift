import Foundation

/// The days of one month laid out in a 7-column grid starting on the calendar's first weekday (DESIGN.md §4.9).
struct MonthGrid: Equatable {
    /// Start of the month's first day.
    let month: Date
    /// Empty cells before day 1.
    let leadingBlanks: Int
    /// Start of each day of the month, in order.
    let days: [Date]
    /// Short weekday names in column order, e.g. Mon … Sun for a Monday-first calendar.
    let weekdaySymbols: [String]
    /// One-letter weekday names in column order (M … S), for accessibility text sizes.
    let narrowWeekdaySymbols: [String]

    init(containing date: Date, calendar: Calendar = .current) {
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        self.month = month
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: month) }
        leadingBlanks = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
        weekdaySymbols = order.map { calendar.shortStandaloneWeekdaySymbols[$0] }
        narrowWeekdaySymbols = order.map { calendar.veryShortStandaloneWeekdaySymbols[$0] }
    }

    /// The grid for the month `offset` months away.
    func moved(by offset: Int, calendar: Calendar = .current) -> MonthGrid {
        MonthGrid(containing: calendar.date(byAdding: .month, value: offset, to: month)!, calendar: calendar)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }
}
