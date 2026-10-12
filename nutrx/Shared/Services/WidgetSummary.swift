import Foundation

/// Text the widgets show (DESIGN.md §5.10). Compiled into the app and the widget extension, so it's tested
/// from `nutrxTests`.
enum WidgetSummary {
    /// "3/6".
    static func score(met: Int, total: Int) -> String {
        "\(met)/\(total)"
    }

    /// "10-day streak", or nil when streaks are off or there isn't one.
    static func streak(days: Int, enabled: Bool) -> String? {
        enabled && days >= 1 ? "\(days)-day streak" : nil
    }

    /// The inline Lock Screen line: "3/6 goals · 10-day streak", "3/6 goals", or a prompt with no nutrients.
    static func inline(met: Int, total: Int, streakDays: Int, streaksEnabled: Bool) -> String {
        guard total > 0 else { return "Add a nutrient in nutrx" }
        let goals = "\(score(met: met, total: total)) goals"
        guard let streak = streak(days: streakDays, enabled: streaksEnabled) else { return goals }
        return "\(goals) · \(streak)"
    }

    /// The small widget's footer: the first goal not met yet, in Today's order — or that the day is done.
    static func nextLine(firstUnmetName: String?, total: Int) -> String {
        guard total > 0 else { return "Add a nutrient" }
        guard let firstUnmetName else { return "All done for today" }
        return "Next: \(firstUnmetName)"
    }
}
