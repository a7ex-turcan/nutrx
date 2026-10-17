import Foundation

/// The trailing values on the Settings rows (DESIGN.md §5.9): "On", "Noon check-in", "2".
enum SettingsSummary {
    static func iCloud(hasAccount: Bool, syncEnabled: Bool) -> String {
        guard hasAccount else { return "No account" }
        return syncEnabled ? "On" : "Off"
    }

    /// Settings → iCloud Sync's status: what this launch does, and what changes when nutrx next opens (the store opens
    /// with or without iCloud at launch).
    static func iCloudStatus(hasAccount: Bool, enabled: Bool, active: Bool) -> String {
        guard hasAccount else { return "No iCloud account" }
        switch (active, enabled) {
        case (true, true): return "Syncing"
        case (false, false): return "Off"
        case (true, false): return "Stops when you reopen nutrx"
        case (false, true): return "Starts when you reopen nutrx"
        }
    }

    /// The footer under the switch.
    static func iCloudFooter(enabled: Bool, active: Bool) -> String {
        let privacy = "Your data syncs via your private iCloud container. No one else can see it."
        if enabled != active {
            return "Close nutrx from the app switcher and open it again to apply this. \(privacy)"
        }
        return active ? "\(privacy) To delete nutrx's data from iCloud, turn sync off and reopen nutrx." : privacy
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

    /// The profile card's title: the name, or a prompt when there isn't one.
    static func profileTitle(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your profile" : trimmed
    }
}
