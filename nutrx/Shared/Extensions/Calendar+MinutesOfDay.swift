import Foundation

extension Calendar {
    /// `minutes` after midnight as a time on `day`, for the time pickers that store minutes (reminders, How you
    /// feel's Ask from). Never nil: out-of-range minutes are held to the day (-1, "no time", is midnight), and a day
    /// with no such time falls back to its start. A picker's getter can run once more after its value became -1,
    /// as the section showing it goes away; force-unwrapping `date(bySettingHour:minute:…)` crashed there (2.8 (244)).
    func date(atMinutes minutes: Int, on day: Date = .now) -> Date {
        let minutes = Swift.min(Swift.max(minutes, 0), 24 * 60 - 1)
        return date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? startOfDay(for: day)
    }
}
