import Foundation

/// The words around schedules (nutrx Pro, #132, docs/pro/SCHEDULES.md): Today's Not today section for now, the
/// form's Schedule row and sheet later. Pure, tested in `NutrientScheduleTests`.
struct ScheduleText {
    var calendar: Calendar = .current
    var locale: Locale = .current

    /// Today's collapsed section of running nutrients that aren't due today.
    static let notTodayTitle = "Not today"

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
