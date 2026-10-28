import Foundation
import SwiftData

/// Loads the recaps for the Recaps screen, Today's card and History's row (nutrx Pro, phase 6; months since #136):
/// the last eight weeks and twelve months that have something to sum up, the running week and month, and each one's
/// summary (the template at once, then the on-device rewording when there is one).
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

    /// The Month tab's picker: whole months, then the month so far.
    var monthChoices: [MonthlyRecap] { months + [runningMonth].compactMap { $0 } }
    /// The month shown: the one picked, else the latest whole month, else the month so far (docs/pro/RECAPS.md §5).
    var selectedMonthRecap: MonthlyRecap? {
        monthChoices.first { $0.monthStart == selectedMonth } ?? months.last ?? runningMonth
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
