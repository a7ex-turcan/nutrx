import Foundation

/// When and what the recap notifications say (nutrx Pro, phase 6; months and years since #136): Sunday 18:00 for
/// the week, the 1st at 18:00 for the month just ended, 1 January at 18:00 for the year, one a night. Pure, tested in
/// `WeeklyRecapTests`, `MonthlyRecapTests` and `YearlyRecapTests`; `NotificationService` schedules them with the other
/// reminders.
enum RecapSchedule {
    static let identifierPrefix = "weekly-recap-"
    static let monthIdentifierPrefix = "monthly-recap-"
    static let yearIdentifierPrefix = "yearly-recap-"
    static let identifierPrefixes = [identifierPrefix, monthIdentifierPrefix, yearIdentifierPrefix]
    static let category = "nutrx.recap"
    static let turnOffAction = "nutrx.recap.turnOff"
    /// The notification's period ("week", "month", "year"), so a tap opens that tab.
    static let periodKey = "recapPeriod"

    /// The device's setting (Settings → Notifications → Recaps), on unless turned off. The key is the weekly
    /// recap's from before #136, so an existing choice carries over to all three.
    static let enabledKey = "nutrx.weeklyRecapNotifications"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    struct Plan: Equatable {
        let identifier: String
        let fireDate: Date
        var title = RecapText.notificationTitle
        let body: String
        var tab = RecapTab.week
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

    /// The month's notification, on the next 1st at 18:00, once something was logged that month. Numbers in the
    /// body only when set up on the 1st itself, as for the week.
    static func plan(month recap: MonthlyRecap, now: Date, calendar: Calendar = .current) -> Plan? {
        let fire = MonthlyRecap.releaseDate(ofMonthStarting: recap.monthStart, calendar: calendar)
        guard fire > now, recap.daysLoggedSoFar > 0 else { return nil }
        let text = MonthlyRecapText(recap, calendar: calendar)
        let day = calendar.dateComponents([.year, .month], from: recap.monthStart)
        return Plan(identifier: monthIdentifierPrefix + String(format: "%04d%02d", day.year ?? 0, day.month ?? 0),
                    fireDate: fire, title: text.notificationTitle,
                    body: calendar.isDate(now, inSameDayAs: fire) ? text.notificationBody : text.notificationBodyWithoutFacts,
                    tab: .month)
    }

    /// The year's notification, on 1 January at 18:00, once something was logged that year.
    static func plan(year recap: YearlyRecap, now: Date, calendar: Calendar = .current) -> Plan? {
        let fire = YearlyRecap.releaseDate(ofYearStarting: recap.yearStart, calendar: calendar)
        guard fire > now, recap.daysLoggedSoFar > 0 else { return nil }
        let text = YearlyRecapText(recap, calendar: calendar)
        return Plan(identifier: yearIdentifierPrefix + text.yearName, fireDate: fire, title: text.notificationTitle,
                    body: calendar.isDate(now, inSameDayAs: fire) ? text.notificationBody : text.notificationBodyWithoutFacts,
                    tab: .year)
    }

    /// One recap a night (docs/pro/RECAPS.md §6): the year's and December's both land on 1 January, a month's and a
    /// week's on a 1st that's a Sunday. Only the longest goes; the others are a tab away.
    static func oneANight(_ plans: [Plan], calendar: Calendar = .current) -> [Plan] {
        let longestFirst = plans.sorted { RecapTab.allCases.firstIndex(of: $0.tab)! > RecapTab.allCases.firstIndex(of: $1.tab)! }
        var kept: [Plan] = []
        for plan in longestFirst where !kept.contains(where: { calendar.isDate($0.fireDate, inSameDayAs: plan.fireDate) }) {
            kept.append(plan)
        }
        return kept.sorted { $0.fireDate < $1.fireDate }
    }

    /// The month the next monthly notification is for: last month until the 1st's 18:00, then this one.
    static func upcomingMonth(at now: Date, calendar: Calendar = .current) -> Date {
        let lastMonth = MonthlyRecap.latestMonth(at: now, calendar: calendar)
        return now < MonthlyRecap.releaseDate(ofMonthStarting: lastMonth, calendar: calendar)
            ? lastMonth
            : MonthlyRecap.monthStart(containing: now, calendar: calendar)
    }

    /// The year the next yearly notification is for: last year until 1 January's 18:00, then this one.
    static func upcomingYear(at now: Date, calendar: Calendar = .current) -> Date {
        let lastYear = YearlyRecap.latestYear(at: now, calendar: calendar)
        return now < YearlyRecap.releaseDate(ofYearStarting: lastYear, calendar: calendar)
            ? lastYear
            : YearlyRecap.yearStart(containing: now, calendar: calendar)
    }

    /// Whether the year's notification is near enough to set up: in December, and on 1 January until it goes. The
    /// rest of the year the sync after every log doesn't read the year's entries for it.
    static func yearIsDue(at now: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.month, from: now) == 12
            || now < YearlyRecap.releaseDate(ofYearStarting: YearlyRecap.latestYear(at: now, calendar: calendar),
                                             calendar: calendar)
    }

    /// The slots the recaps take of the 60 while the entitlement is unknown: the next week's and month's, plus
    /// the year's when it's due.
    static func slots(at now: Date, calendar: Calendar = .current) -> Int { yearIsDue(at: now, calendar: calendar) ? 3 : 2 }

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
