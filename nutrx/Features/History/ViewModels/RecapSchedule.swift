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

    /// The month whose "Your October" card Today shows at `now` (#136): Pro only, on the next month's 1st and 2nd (or
    /// any day with `ignoresWindow`, the Debug flag), and not hidden with ✕ for that month. When it shows, it takes the
    /// week card's place (the longer period wins, docs/pro/RECAPS.md §6). The month needs something in it too.
    static func todayCardMonth(at now: Date, isPro: Bool, dismissedMonth: Date?, ignoresWindow: Bool = false,
                               calendar: Calendar = .current) -> Date? {
        let month = MonthlyRecap.latestMonth(at: now, calendar: calendar)
        guard isPro, ignoresWindow || showsTodayCard(forMonthStarting: month, at: now, calendar: calendar),
              month != dismissedMonth else { return nil }
        return month
    }

    /// The recap History's row names and opens on (#136): the one out last. A month's comes out on the 1st and a
    /// year's on 1 January, at 18:00 like the week's on Sunday, so last month's leads from the 1st until the next
    /// Sunday's recap. On a tie (a Sunday 1st; 1 January's year and December) the longer period wins.
    static func latestTab(week: Date?, month: Date?, year: Date?, calendar: Calendar = .current) -> RecapTab {
        let releases: [(tab: RecapTab, date: Date)] = [
            year.map { (.year, YearlyRecap.releaseDate(ofYearStarting: $0, calendar: calendar)) },
            month.map { (.month, MonthlyRecap.releaseDate(ofMonthStarting: $0, calendar: calendar)) },
            week.map { (.week, WeeklyRecap.releaseDate(ofWeekStarting: $0, calendar: calendar)) },
        ].compactMap { $0 }
        // Longest first, and only a later date replaces it.
        let latest = releases.reduce(nil) { (best: (tab: RecapTab, date: Date)?, next) in
            best.map { next.date > $0.date ? next : $0 } ?? next
        }
        return latest?.tab ?? .week
    }

    /// The year whose "Your 2026" card Today shows at `now` (#136): Pro only, from 1 to 7 January (or any day with
    /// `ignoresWindow`, the Debug flag), and not hidden with ✕ for that year. It takes the month's and the week's
    /// place. The year needs something in it too.
    static func todayCardYear(at now: Date, isPro: Bool, dismissedYear: Date?, ignoresWindow: Bool = false,
                              calendar: Calendar = .current) -> Date? {
        let year = YearlyRecap.latestYear(at: now, calendar: calendar)
        guard isPro, ignoresWindow || showsTodayCard(forYearStarting: year, at: now, calendar: calendar),
              year != dismissedYear else { return nil }
        return year
    }

    /// Today's "Your 2026" card shows from 1 to 7 January 2027.
    static func showsTodayCard(forYearStarting year: Date, at now: Date, calendar: Calendar = .current) -> Bool {
        let next = calendar.date(byAdding: .year, value: 1, to: year)!
        let eighth = calendar.date(byAdding: .day, value: 7, to: next)!
        return now >= next && now < eighth
    }

    /// Today's "Your October" card shows on 1 and 2 November.
    static func showsTodayCard(forMonthStarting month: Date, at now: Date, calendar: Calendar = .current) -> Bool {
        let next = calendar.date(byAdding: .month, value: 1, to: month)!
        let third = calendar.date(byAdding: .day, value: 2, to: next)!
        return now >= next && now < third
    }

    /// Today's "Your week" card shows from the recap's Sunday 18:00 until Monday ends.
    static func showsTodayCard(forWeekStarting weekStart: Date, at now: Date, calendar: Calendar = .current) -> Bool {
        let release = WeeklyRecap.releaseDate(ofWeekStarting: weekStart, calendar: calendar)
        let tuesday = calendar.date(byAdding: .day, value: 8, to: weekStart)!
        return now >= release && now < tuesday
    }
}
