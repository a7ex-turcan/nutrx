import Foundation
import SwiftData

/// Loads the weekly recaps for the Recap screen, Today's card and History's row (nutrx Pro, phase 6): the last
/// eight weeks that have something to sum up, the running week for the first-week state, and each week's summary
/// (the template at once, then the on-device rewording when there is one).
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
    }

    /// One week's recap, or nil when it has nothing in it (Today's card). Only that week's entries are read.
    static func recap(forWeek week: Date, context: ModelContext, streaksEnabled: Bool, now: Date = .now) -> WeeklyRecap? {
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now, from: week)
        let names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let recap = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: streaksEnabled)
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
