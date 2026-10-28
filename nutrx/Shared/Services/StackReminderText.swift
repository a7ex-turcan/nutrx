import Foundation

/// A stack reminder's words (#137, docs/pro/REMINDERS.md §4): the notification, the stack's Reminder row and the
/// sheet's note about its nutrients' own reminders. Pure.
enum StackReminderText {
    /// "Time for your Morning stack"; a name that already ends in "stack" isn't doubled.
    static func title(stackName: String) -> String {
        "Time for your \(fullName(stackName))"
    }

    /// "Vitamin D, Omega-3 and Magnesium".
    static func body(names: [String]) -> String {
        guard let last = names.last else { return "Tap to log it." }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// "Morning" → "Morning stack"; a name ending in "stack" ("Morning stack") stays as it is.
    static func fullName(_ stackName: String) -> String {
        stackName.lowercased().hasSuffix("stack") ? stackName : "\(stackName) stack"
    }

    /// The Reminder row: "None", "9:00", or at its usual time "Usually by 8:30", "Learning (9:00)".
    static func summary(minutes: Int, atUsualTime: Bool, usual: UsualTime.Result, isPro: Bool,
                        calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard minutes >= 0 else { return "None" }
        let start = UsualTimeText.time(minutes, calendar: calendar, locale: locale)
        guard atUsualTime else { return start }
        return UsualTimeText.summary(usual, start: start, isPro: isPro, calendar: calendar, locale: locale)
    }

    /// Under the sheet: "Vitamin D and Omega-3 have reminders of their own too.", or nil when none has.
    static func ownRemindersNote(names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        let list = body(names: names)
        return "\(list) \(names.count == 1 ? "has a reminder" : "have reminders") of \(names.count == 1 ? "its" : "their") own too."
    }
}
