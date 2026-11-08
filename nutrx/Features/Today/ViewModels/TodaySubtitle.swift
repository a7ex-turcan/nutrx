import Foundation

/// Today's date under the large title: "Saturday 7 November", or "Sat 7 Nov" at accessibility sizes, where the full
/// date ran out of room on one line ("Saturday, 7 Novemb…", #360). In the locale's order. Pure.
enum TodaySubtitle {
    static func text(for date: Date, isAccessibilitySize: Bool, locale: Locale = .current,
                     calendar: Calendar = .current) -> String {
        var style = isAccessibilitySize
            ? Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
            : Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
