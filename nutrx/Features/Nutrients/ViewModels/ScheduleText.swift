import Foundation

/// The words around schedules (nutrx Pro, #132, docs/pro/SCHEDULES.md): Today's Not today section for now, the
/// form's Schedule row and sheet later. Pure, tested in `NutrientScheduleTests`.
struct ScheduleText {
    var calendar: Calendar = .current
    var locale: Locale = .current

    /// Today's collapsed section of running nutrients that aren't due today.
    static let notTodayTitle = "Not today"

    /// The form's Schedule row: "Every day", "Mon, Wed, Fri", "Weekdays", "Sundays", "Every other day",
    /// "Every 3 days", "5 days on, 2 off", "3 weeks on, 1 off", "3 times a week".
    func summary(_ kind: NutrientSchedule.Kind) -> String {
        switch kind {
        case .everyDay:
            return "Every day"
        case .weekdays(let days):
            if days.count == 7 { return "Every day" }
            if days == [2, 3, 4, 5, 6] { return "Weekdays" }
            if days == [1, 7] { return "Weekends" }
            if days.count == 1, let day = days.first { return weekdayNames(.wide)[day - 1] + "s" }
            let names = weekdayNames(.abbreviated)
            return ordered(days).map { names[$0 - 1] }.joined(separator: ", ")
        case .cycle(let on, let off, _):
            if on == 1 { return off == 1 ? "Every other day" : "Every \(off + 1) days" }
            if on % 7 == 0, off % 7 == 0 {
                return "\(on / 7) \(on == 7 ? "week" : "weeks") on, \(off / 7) off"
            }
            return "\(on) \(on == 1 ? "day" : "days") on, \(off) off"
        case .weekly(let times):
            switch times {
            case 1: return "Once a week"
            case 2: return "Twice a week"
            default: return "\(times) times a week"
            }
        }
    }

    /// The sheet's footer: the next two days it's due from today: "Today, then Wed 28 Oct." or
    /// "Next: Sun 25 Oct, then Sun 1 Nov."
    func upcoming(_ kind: NutrientSchedule.Kind, today: Date) -> String {
        let start = calendar.startOfDay(for: today)
        let schedule = NutrientSchedule().setting(kind, from: start, calendar: calendar)
        var days: [Date] = []
        if schedule.isDoseDay(start, calendar: calendar) { days.append(start) }
        var day = start
        while days.count < 2, let next = schedule.nextDoseDay(after: day, calendar: calendar) {
            days.append(next)
            day = next
        }
        guard let first = days.first else { return "" }
        let firstText = first == start ? "Today" : "Next: " + date(first)
        guard days.count > 1 else { return firstText + "." }
        return "\(firstText), then \(date(days[1]))."
    }

    /// Weekday numbers (1 = Sunday) in the locale's order: Monday first in most of Europe, Sunday in the US.
    func ordered(_ days: some Collection<Int>) -> [Int] {
        let first = calendar.firstWeekday
        return days.sorted { ($0 - first + 7) % 7 < ($1 - first + 7) % 7 }
    }

    enum NameWidth { case wide, abbreviated, narrow }

    /// The seven weekday names, Sunday first, in this locale.
    func weekdayNames(_ width: NameWidth) -> [String] {
        var named = calendar
        named.locale = locale
        switch width {
        case .wide: return named.standaloneWeekdaySymbols
        case .abbreviated: return named.shortStandaloneWeekdaySymbols
        case .narrow: return named.veryShortStandaloneWeekdaySymbols
        }
    }

    private func date(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// A Not today row: "Next: tomorrow", "Next: Sunday" within the week, "Next: Mon 2 Nov" after that, or
    /// "Course ends first" when its course is over before its next day.
    func next(_ nextDue: Date?, today: Date) -> String {
        guard let nextDue else { return "Course ends first" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today),
                                           to: calendar.startOfDay(for: nextDue)).day ?? 0
        if days <= 1 { return "Next: tomorrow" }
        let style = days < 7 ? Date.FormatStyle.dateTime.weekday(.wide)
                             : Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        var formatted = style.locale(locale)
        formatted.timeZone = calendar.timeZone
        return "Next: " + nextDue.formatted(formatted)
    }
}
