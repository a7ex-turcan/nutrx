import Foundation

/// When and what the Sunday-evening recap notification says (nutrx Pro, phase 6). Pure, tested in
/// `WeeklyRecapTests`; `NotificationService` schedules it with the other reminders.
enum RecapSchedule {
    static let identifierPrefix = "weekly-recap-"
    static let category = "nutrx.recap"
    static let turnOffAction = "nutrx.recap.turnOff"

    /// The device's setting (Settings → Notifications), on unless turned off.
    static let enabledKey = "nutrx.weeklyRecapNotifications"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    struct Plan: Equatable {
        let identifier: String
        let fireDate: Date
        let body: String
    }

    /// The next recap notification, for the week whose Sunday 18:00 comes next — only once something has been
    /// logged that week, so a quiet week gets no notification. The body has the week's numbers only when set up
    /// on that Sunday; earlier in the week they'd be out of date by the time it arrives.
    static func plan(recap: WeeklyRecap, now: Date, calendar: Calendar = .current) -> Plan? {
        let fire = WeeklyRecap.releaseDate(ofWeekStarting: recap.weekStart, calendar: calendar)
        guard fire > now, recap.daysLoggedSoFar > 0 else { return nil }
        let text = RecapText(recap, calendar: calendar)
        let body = calendar.isDate(now, inSameDayAs: fire) ? text.notificationBody : RecapText.notificationBodyWithoutFacts
        let day = calendar.dateComponents([.year, .month, .day], from: recap.weekStart)
        let id = identifierPrefix + String(format: "%04d%02d%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return Plan(identifier: id, fireDate: fire, body: body)
    }

    /// The week the next notification is for: this week until its Sunday 18:00, then next week.
    static func upcomingWeek(at now: Date, calendar: Calendar = .current) -> Date {
        let thisWeek = WeeklyRecap.weekStart(containing: now, calendar: calendar)
        return now < WeeklyRecap.releaseDate(ofWeekStarting: thisWeek, calendar: calendar)
            ? thisWeek
            : calendar.date(byAdding: .day, value: 7, to: thisWeek)!
    }

    /// The week whose "Your week" card Today shows at `now`, if any: Pro only, from its Sunday 18:00 through Monday
    /// (or any day with `ignoresWindow`, the Debug flag), and not hidden with ✕ for that week. The card also needs
    /// the week to have something in it (`RecapViewModel.recap(forWeek:…)`).
    static func todayCardWeek(at now: Date, isPro: Bool, dismissedWeek: Date?, ignoresWindow: Bool = false,
                              calendar: Calendar = .current) -> Date? {
        let week = WeeklyRecap.latestWeek(at: now, calendar: calendar)
        guard isPro, ignoresWindow || showsTodayCard(forWeekStarting: week, at: now, calendar: calendar),
              week != dismissedWeek else { return nil }
        return week
    }

    /// Today's "Your week" card shows from the recap's Sunday 18:00 until Monday ends.
    static func showsTodayCard(forWeekStarting weekStart: Date, at now: Date, calendar: Calendar = .current) -> Bool {
        let release = WeeklyRecap.releaseDate(ofWeekStarting: weekStart, calendar: calendar)
        let tuesday = calendar.date(byAdding: .day, value: 8, to: weekStart)!
        return now >= release && now < tuesday
    }
}
