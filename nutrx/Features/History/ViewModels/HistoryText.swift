import Foundation

/// Strings for the History screens (DESIGN.md §5.4, §5.5).
enum HistoryText {
    /// "10 days", "1 day".
    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    /// The day summary under "4 of 6 goals": who was missed, by name while that stays short.
    static func missedLine(missedNames: [String], goalCount: Int, locale: Locale = .current) -> String {
        if goalCount == 0 { return "Nothing was tracked that day" }
        switch missedNames.count {
        case 0:
            return "Every goal met"
        case 1...3:
            return "Missed \(missedNames.formatted(.list(type: .and).locale(locale)))"
        default:
            return "Missed \(missedNames.count) goals"
        }
    }

    /// "4 of 6 goals" — "1 of 1 goal".
    static func goalsLine(met: Int, total: Int) -> String {
        "\(met) of \(total) \(GoalProgress.goals(total))"
    }

    /// The year grid's title (§4.9a): "142 full days in the last year", "1 full day …", "No full days …".
    static func fullDaysInLastYear(_ count: Int) -> String {
        switch count {
        case 0: "No full days in the last year"
        case 1: "1 full day in the last year"
        default: "\(count) full days in the last year"
        }
    }

    /// The year grid's picked day: "Tue, 4 Nov · 3 of 4 goals", "Today · 2 of 4 goals", "Sun, 2 Nov · Nothing logged".
    static func yearDayLine(date: Date, completion: DayCompletion, met: Int, total: Int, isToday: Bool,
                            locale: Locale = .current) -> String {
        let day = isToday ? "Today" : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
        let status = switch completion {
        case .noEntries: "Nothing logged"
        case .rest: "Nothing due"
        case .noneMet, .someMet, .allMet: goalsLine(met: met, total: total)
        }
        return "\(day) · \(status)"
    }
}
