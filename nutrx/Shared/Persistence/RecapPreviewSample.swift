import Foundation

#if DEBUG
/// Recaps for previews: two nutrients from 1 January this year to yesterday, Omega-3 missed every Sunday and
/// everything missed every ninth day.
enum RecapPreviewSample {
    private static let vitaminD = UUID()
    private static let omega = UUID()

    static var log: HistoryLog {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = YearlyRecap.yearStart(containing: today, calendar: calendar)
        let nutrients = [
            HistoryNutrient(id: vitaminD, goalType: .minimum, target: 1000, upperBound: nil, createdAt: start, isRemoved: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 500, upperBound: nil, createdAt: start, isRemoved: false),
        ]
        var totals: [Date: [UUID: Double]] = [:]
        var day = start
        var index = 0
        while day < today {
            let sunday = calendar.component(.weekday, from: day) == 1
            totals[day] = index % 9 == 8 ? [vitaminD: 0, omega: 0] : [vitaminD: 1000, omega: sunday ? 0 : 500]
            day = calendar.date(byAdding: .day, value: 1, to: day)!
            index += 1
        }
        return HistoryLog(nutrients: nutrients, totals: totals, today: today)
    }

    static var names: [UUID: String] { [vitaminD: "Vitamin D", omega: "Omega-3"] }

    static var month: MonthlyRecap {
        MonthlyRecap.build(log: log, names: names, month: MonthlyRecap.latestMonth(at: .now, calendar: .current),
                           streaksEnabled: true)
    }

    static var year: YearlyRecap { YearlyRecap.build(log: log, names: names, year: .now, streaksEnabled: true) }
}
#endif
