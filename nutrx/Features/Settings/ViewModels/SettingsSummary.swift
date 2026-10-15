import Foundation

/// The trailing values on the Settings rows (DESIGN.md §5.9): "On", "Noon check-in", "2".
enum SettingsSummary {
    static func iCloud(hasAccount: Bool, syncEnabled: Bool) -> String {
        guard hasAccount else { return "No account" }
        return syncEnabled ? "On" : "Off"
    }

    /// `weeklyRecap`: the Pro recap will actually arrive (Pro, its switch on, notifications allowed).
    static func notifications(dailyReminderEnabled: Bool, weeklyRecap: Bool = false) -> String {
        switch (dailyReminderEnabled, weeklyRecap) {
        case (true, true): "Check-in and recap"
        case (true, false): "Noon check-in"
        case (false, true): "Weekly recap"
        case (false, false): "Off"
        }
    }

    static func streaks(enabled: Bool) -> String {
        enabled ? "On" : "Off"
    }

    /// Groups the user made — General isn't counted.
    static func groups(userGroupCount: Int) -> String {
        userGroupCount == 0 ? "None" : "\(userGroupCount)"
    }

    /// Stacks the user made.
    static func stacks(count: Int) -> String {
        count == 0 ? "None" : "\(count)"
    }

    /// The profile card's title: the name, or a prompt when there isn't one.
    static func profileTitle(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your profile" : trimmed
    }
}
