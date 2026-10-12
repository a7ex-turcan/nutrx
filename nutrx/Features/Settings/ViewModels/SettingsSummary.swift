import Foundation

/// The trailing values on the Settings rows (DESIGN.md §5.9): "On", "Noon check-in", "2".
enum SettingsSummary {
    static func iCloud(hasAccount: Bool, syncEnabled: Bool) -> String {
        guard hasAccount else { return "No account" }
        return syncEnabled ? "On" : "Off"
    }

    static func notifications(dailyReminderEnabled: Bool) -> String {
        dailyReminderEnabled ? "Noon check-in" : "Off"
    }

    static func streaks(enabled: Bool) -> String {
        enabled ? "On" : "Off"
    }

    /// Groups the user made — General isn't counted.
    static func groups(userGroupCount: Int) -> String {
        userGroupCount == 0 ? "None" : "\(userGroupCount)"
    }

    /// The profile card's title: the name, or a prompt when there isn't one.
    static func profileTitle(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your profile" : trimmed
    }
}
