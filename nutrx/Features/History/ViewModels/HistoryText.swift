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
}
