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

    /// The Watch's inline complication: "3/6 goals · 10 days" (shorter than the Lock Screen's "10-day streak").
    static func watchInline(met: Int, total: Int, streakDays: Int, streaksEnabled: Bool) -> String {
        guard total > 0 else { return "nutrx" }
        let goals = "\(score(met: met, total: total)) goals"
        guard streaksEnabled, streakDays >= 1 else { return goals }
        return "\(goals) · \(streakDays == 1 ? "1 day" : "\(streakDays) days")"
    }

    /// The Watch's confirmation pill after a + tap: "+1,000 logged".
    static func logged(_ amount: Double, locale: Locale = .current) -> String {
        "+\(amount.formattedAmount(locale: locale)) logged"
    }

    /// VoiceOver announcement after a Watch + tap: "Logged 1,000 IU of Vitamin D. 3,000 of 4,000 IU."
    /// `progress` is `GoalProgress.progressText` for the new total.
    static func loggedAnnouncement(_ amount: Double, unit: String, name: String, progress: String,
                                   locale: Locale = .current) -> String {
        let number = amount.formattedAmount(locale: locale)
        let logged = unit.isEmpty ? number : "\(number) \(unit)"
        return "Logged \(logged) of \(name). \(progress)."
    }

    /// Segments for a goals bar: one per goal up to `maxSegments`; beyond that, the met share scaled to fit
    /// (rounded down, so a bar only looks full when every goal is met).
    static func segments(met: Int, total: Int, maxSegments: Int = 12) -> (filled: Int, count: Int) {
        guard total > 0 else { return (0, 0) }
        let met = min(max(met, 0), total)
        guard total > maxSegments else { return (met, total) }
        return (met * maxSegments / total, maxSegments)
    }

    /// The small widget's footer: the first goal that still needs more, in Today's order. With none left, how
    /// many are over a limit, or that the day is done.
    static func nextLine(firstUnmetName: String?, overLimitCount: Int = 0, total: Int) -> String {
        guard total > 0 else { return "Add a nutrient" }
        if let firstUnmetName { return "Next: \(firstUnmetName)" }
        return overLimitCount > 0 ? overLimit(overLimitCount) : "All done for today"
    }

    /// "1 over limit": goals past an "at most" limit or a range's upper bound.
    static func overLimit(_ count: Int) -> String {
        "\(count) over limit"
    }
}
