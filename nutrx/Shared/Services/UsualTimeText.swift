import Foundation

/// The words around a usual-time reminder (nutrx Pro, #137, docs/pro/REMINDERS.md §3, §4): the reminders sheets'
/// explanation and the Reminders row. Pure.
enum UsualTimeText {
    /// "8:30" for minutes after midnight, in the locale's style.
    static func time(_ minutes: Int, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1,
                                                           hour: minutes / 60, minute: minutes % 60))!
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return reference.formatted(style)
    }

    /// The sheet's footer under the choice. `start` is the starting time ("9:00"), nil before one is set; `name`
    /// is what it reminds about ("Vitamin D", "your Morning stack").
    static func explanation(_ result: UsualTime.Result, start: String?, isPro: Bool, name: String,
                            calendar: Calendar = .current, locale: Locale = .current) -> String {
        let until = start.map { "nutrx reminds you at \($0)" } ?? "nutrx reminds you at the time you set below"
        guard isPro else { return "Reminders at your usual time are part of nutrx Pro. Until then, \(until)." }
        switch result {
        case let .learned(weekdays, weekends) where weekdays == weekends:
            return "You usually log \(name) by \(time(weekdays, calendar: calendar, locale: locale)). "
                + "nutrx reminds you then, only if you haven't logged it."
        case let .learned(weekdays, weekends):
            return "You usually log \(name) by \(time(weekdays, calendar: calendar, locale: locale)) on weekdays and "
                + "\(time(weekends, calendar: calendar, locale: locale)) at weekends. "
                + "nutrx reminds you then, only if you haven't logged it."
        case let .learning(samples):
            return "Learning your usual time: \(samples) of \(UsualTime.minimumSamples) days logged. Until then, \(until)."
        case .tooLate:
            return "You usually log \(name) close to midnight, so \(until)."
        }
    }

    /// Under the starting time: when it's used, and with two or more set times that they wait for switching back.
    static func startingTimeFooter(_ result: UsualTime.Result, name: String, setTimes: Int) -> String {
        let start = switch result {
        case .learning: "Used until nutrx has learned when you usually log \(name)."
        case .learned: "Used instead if nutrx Pro ends."
        case .tooLate: "Used while you log \(name) close to midnight."
        }
        guard setTimes >= 2 else { return start }
        return "\(start) One reminder a day, for the first time you log it. Your \(setTimes) set times come back if "
            + "you switch back."
    }

    /// The Reminders row in usual mode: "Usually by 8:30", "8:30, weekends 10:15", "Learning (9:00)", or the starting
    /// time alone (around midnight, without Pro).
    static func summary(_ result: UsualTime.Result, start: String?, isPro: Bool,
                        calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard isPro else { return start ?? "None" }
        switch result {
        case let .learned(weekdays, weekends) where weekdays == weekends:
            return "Usually by \(time(weekdays, calendar: calendar, locale: locale))"
        case let .learned(weekdays, weekends):
            return "\(time(weekdays, calendar: calendar, locale: locale)), weekends \(time(weekends, calendar: calendar, locale: locale))"
        case .learning:
            return start.map { "Learning (\($0))" } ?? "Learning"
        case .tooLate:
            return start ?? "None"
        }
    }
}
