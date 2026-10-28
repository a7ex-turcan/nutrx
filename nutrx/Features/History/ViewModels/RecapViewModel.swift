import Foundation
import SwiftData

/// Which recap the Recaps screen shows (#136, docs/pro/RECAPS.md §5).
enum RecapTab: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: Self { self }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

/// Loads the recaps for the Recaps screen, Today's card and History's row (nutrx Pro, phase 6; months and years since
/// #136): the last eight weeks, twelve months and three years that have something to sum up, the running week, month
/// and year, and each one's summary (the template at once, then the on-device rewording when there is one).
@MainActor
@Observable
final class RecapViewModel {
    /// How many weeks the "Earlier weeks" row goes back.
    static let weekCount = 8

    /// Weeks with a recap, oldest first, the newest last.
    private(set) var weeks: [WeeklyRecap] = []
    /// The week still running, for "Your first recap arrives Sunday".
    private(set) var runningWeek: WeeklyRecap?
    /// Each week's summary once worded, by week start.
    private(set) var summaries: [Date: String] = [:]
    private(set) var nutrientsByID: [UUID: Nutrient] = [:]
    /// The week the screen shows; nil is the newest.
    var selectedWeek: Date?

    /// How many months "Earlier months" goes back.
    static let monthCount = 12

    /// Whole months with a recap, oldest first.
    private(set) var months: [MonthlyRecap] = []
    /// The month so far, once it has a completed day (not on the 1st).
    private(set) var runningMonth: MonthlyRecap?
    /// Days logged this month, today included, and the month's length: the first-month state's ring.
    private(set) var monthDaysLoggedSoFar = 0
    private(set) var monthLength = 30
    private(set) var monthSummaries: [Date: String] = [:]
    /// The month the Month tab shows; nil is the default (`selectedMonthRecap`).
    var selectedMonth: Date?

    /// The Month tab's picker: whole months, then the month so far, twelve at most, so no month's name shows twice
    /// (October so far pushes out last October).
    var monthChoices: [MonthlyRecap] { Array((months + [runningMonth].compactMap { $0 }).suffix(Self.monthCount)) }
    /// The month shown: the one picked, else the latest whole month, else the month so far (docs/pro/RECAPS.md §5).
    var selectedMonthRecap: MonthlyRecap? {
        monthChoices.first { $0.monthStart == selectedMonth } ?? months.last ?? runningMonth
    }

    /// How many whole years "Earlier years" goes back (the summaries' cache keeps three).
    static let yearCount = 3

    /// Whole years with a recap, oldest first.
    private(set) var years: [YearlyRecap] = []
    /// The year so far, once it has a completed day (not on 1 January).
    private(set) var runningYear: YearlyRecap?
    /// Days logged this year, today included: the first-year state's ring.
    private(set) var yearDaysLoggedSoFar = 0
    private(set) var yearLength = 365
    private(set) var yearSummaries: [Date: String] = [:]
    /// The year the Year tab shows; nil is the default (`selectedYearRecap`).
    var selectedYear: Date?
    /// Whether it's January, when the Year tab opens on the year just ended.
    private(set) var isJanuary = false
    /// Whether `years` is from the last refresh (`loadYears`).
    private(set) var yearsLoaded = false
    /// The last refresh's log, for `loadYears`.
    private var loaded: (log: HistoryLog, names: [UUID: String], streaksEnabled: Bool, now: Date)?

    /// The Year tab's picker: whole years, then the year so far.
    var yearChoices: [YearlyRecap] { years + [runningYear].compactMap { $0 } }
    /// The year shown: the one picked, else the year so far, except in January, when it's the year just ended
    /// (docs/pro/RECAPS.md §5).
    var selectedYearRecap: YearlyRecap? {
        if let picked = yearChoices.first(where: { $0.yearStart == selectedYear }) { return picked }
        return isJanuary ? years.last ?? runningYear : runningYear ?? years.last
    }

    var latest: WeeklyRecap? { weeks.last }
    var selected: WeeklyRecap? { weeks.first { $0.weekStart == selectedWeek } ?? weeks.last }
    var isFirstWeek: Bool { weeks.isEmpty }

    func refresh(context: ModelContext, streaksEnabled: Bool, now: Date = .now) {
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now)
        nutrientsByID = Dictionary(nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let names = nutrientsByID.mapValues(\.name)
        let calendar = log.calendar
        let newest = WeeklyRecap.latestWeek(at: now, calendar: calendar)
        weeks = (0..<Self.weekCount).reversed().compactMap { back in
            let week = calendar.date(byAdding: .day, value: -7 * back, to: newest)!
            let recap = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: streaksEnabled)
            return recap.hasData ? recap : nil
        }
        let thisWeek = WeeklyRecap.weekStart(containing: now, calendar: calendar)
        runningWeek = WeeklyRecap.build(log: log, names: names, week: thisWeek, streaksEnabled: streaksEnabled)
        if let selectedWeek, !weeks.contains(where: { $0.weekStart == selectedWeek }) { self.selectedWeek = nil }

        let lastMonth = MonthlyRecap.latestMonth(at: now, calendar: calendar)
        months = (0..<Self.monthCount).reversed().compactMap { back in
            let month = calendar.date(byAdding: .month, value: -back, to: lastMonth)!
            let recap = MonthlyRecap.build(log: log, names: names, month: month, streaksEnabled: streaksEnabled)
            return recap.hasData ? recap : nil
        }
        let thisMonth = MonthlyRecap.build(log: log, names: names, month: now, streaksEnabled: streaksEnabled)
        runningMonth = thisMonth.daysElapsed > 0 && thisMonth.hasData ? thisMonth : nil
        monthDaysLoggedSoFar = thisMonth.daysLoggedSoFar
        monthLength = thisMonth.fullDayFlags.count
        if let selectedMonth, !monthChoices.contains(where: { $0.monthStart == selectedMonth }) { self.selectedMonth = nil }

        loaded = (log, names, streaksEnabled, now)
        yearsLoaded = false
    }

    /// The years, built from the last refresh's log the first time the Year tab shows after it: four years of
    /// tallies are too much to build on every open of the week.
    func loadYears() {
        guard !yearsLoaded, let (log, names, streaksEnabled, now) = loaded else { return }
        yearsLoaded = true
        let calendar = log.calendar
        let lastYear = YearlyRecap.latestYear(at: now, calendar: calendar)
        years = (0..<Self.yearCount).reversed().compactMap { back in
            let year = calendar.date(byAdding: .year, value: -back, to: lastYear)!
            let recap = YearlyRecap.build(log: log, names: names, year: year, streaksEnabled: streaksEnabled)
            return recap.hasData ? recap : nil
        }
        let thisYear = YearlyRecap.build(log: log, names: names, year: now, streaksEnabled: streaksEnabled)
        runningYear = thisYear.daysElapsed > 0 && thisYear.hasData ? thisYear : nil
        yearDaysLoggedSoFar = thisYear.daysLoggedSoFar
        yearLength = YearlyRecap.days(ofYearStarting: thisYear.yearStart, calendar: calendar).count
        isJanuary = calendar.component(.month, from: now) == 1
        if let selectedYear, !yearChoices.contains(where: { $0.yearStart == selectedYear }) { self.selectedYear = nil }
    }

    /// One year's recap, or nil when it has nothing in it (Today's card).
    static func recap(forYear year: Date, context: ModelContext, now: Date = .now) -> YearlyRecap? {
        // From the Monday of 1 January's week: a weekly nutrient's met days before New Year decide which of its
        // days in that week count, as in the Year tab's full log.
        let from = NutrientSchedule.weekStart(of: year)
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now, from: from)
        let names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let recap = YearlyRecap.build(log: log, names: names, year: year, streaksEnabled: true)
        return recap.hasData ? recap : nil
    }

    /// The year's summary: the template straight away, the rewording when it's ready.
    func summary(for recap: YearlyRecap) -> String {
        yearSummaries[recap.yearStart] ?? YearlyRecapText(recap).summary
    }

    func loadSummary(for recap: YearlyRecap) async {
        guard yearSummaries[recap.yearStart] == nil else { return }
        yearSummaries[recap.yearStart] = await RecapPhrasing.summary(for: YearlyRecapText(recap))
    }

    /// One month's recap, or nil when it has nothing in it (Today's card). The month before is read too, for the
    /// comparison with last month.
    static func recap(forMonth month: Date, context: ModelContext, now: Date = .now) -> MonthlyRecap? {
        let calendar = Calendar.current
        let from = calendar.date(byAdding: .month, value: -1, to: month)!
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now, from: from)
        let names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let recap = MonthlyRecap.build(log: log, names: names, month: month, streaksEnabled: true)
        return recap.hasData ? recap : nil
    }

    /// The month's summary: the template straight away, the rewording when it's ready.
    func summary(for recap: MonthlyRecap) -> String {
        monthSummaries[recap.monthStart] ?? MonthlyRecapText(recap).summary
    }

    func loadSummary(for recap: MonthlyRecap) async {
        guard monthSummaries[recap.monthStart] == nil else { return }
        monthSummaries[recap.monthStart] = await RecapPhrasing.summary(for: MonthlyRecapText(recap))
    }

    /// One week's recap, or nil when it has nothing in it (Today's card). Only that week's entries are read, so it
    /// has the week's goals, full days, steadiest, slipped and over-limit, but no streak and no weekday you tend to
    /// miss (both look further back): use the full log for those.
    static func recap(forWeek week: Date, context: ModelContext, now: Date = .now) -> WeeklyRecap? {
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now, from: week)
        let names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let recap = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: false)
        return recap.hasData ? recap : nil
    }

    /// The selected week's summary: the template straight away, the rewording when it's ready.
    func summary(for recap: WeeklyRecap) -> String {
        summaries[recap.weekStart] ?? RecapText(recap).summary
    }

    func loadSummary(for recap: WeeklyRecap) async {
        guard summaries[recap.weekStart] == nil else { return }
        let text = await RecapPhrasing.summary(for: RecapText(recap))
        summaries[recap.weekStart] = text
    }
}
