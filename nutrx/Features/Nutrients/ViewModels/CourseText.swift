import Foundation

/// The words around a nutrient taken for a set time (nutrx Pro, #99): the form's Duration row, the sheet and My
/// Nutrients' Finished section. Pure, tested in `CourseTextTests`.
struct CourseText {
    var calendar: Calendar = .current
    var locale: Locale = .current

    static let ongoing = "Ongoing"

    /// The form's Duration row: "Ongoing", "Until Fri 24 Oct · 5 days", "Last day today", "Ended 24 Oct".
    func summary(endDate: Date?, now: Date) -> String {
        guard let endDate else { return Self.ongoing }
        if NutrientCourse.hasEnded(endDate, by: now, calendar: calendar) { return ended(endDate) }
        let days = NutrientCourse.dayCount(from: now, to: endDate, calendar: calendar)
        if days == 1 { return "Last day today" }
        return "Until \(date(endDate, weekday: true)) · \(days) days"
    }

    /// My Nutrients' Finished rows: "Ended 24 Oct".
    func ended(_ endDate: Date) -> String { "Ended \(date(endDate, weekday: false))" }

    /// The sheet's sentence for a number of days from today: "Until Fri 24 Oct, then it leaves Today."
    func untilSentence(_ lastDay: Date) -> String {
        "Until \(date(lastDay, weekday: true)), then it leaves Today. It stays in My Nutrients and History."
    }

    private func date(_ date: Date, weekday: Bool) -> String {
        let style = weekday ? Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
                            : Date.FormatStyle.dateTime.day().month(.abbreviated)
        var formatted = style.locale(locale)
        formatted.timeZone = calendar.timeZone
        return date.formatted(formatted)
    }
}
