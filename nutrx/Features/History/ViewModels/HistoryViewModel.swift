import Foundation
import SwiftData

/// Loads nutrients, intake and exclusions into a `HistoryLog` for the History screens, and tracks the month
/// the calendar shows. The day maths lives in `HistoryLog`; this only fetches and orders.
@Observable
final class HistoryViewModel {
    /// How many days the "Recent days" list shows; older days are reached through the calendar.
    static let recentDayCount = 7

    private(set) var log: HistoryLog?
    private(set) var recentDays: [HistoryDay] = []
    private(set) var streak: StreakResult?
    /// For History's "Weekly recaps" row.
    private(set) var latestRecap: WeeklyRecap?
    private(set) var month = MonthGrid(containing: .now)

    private var nutrientsByID: [UUID: Nutrient] = [:]

    var hasPastEntries: Bool { log?.hasPastEntries ?? false }
    var hasEntries: Bool { log?.hasEntries ?? false }

    func refresh(context: ModelContext, now: Date = .now) {
        let (log, nutrients) = Self.loadLog(context: context, now: now)
        nutrientsByID = Dictionary(nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.log = log
        recentDays = log.recentDays(limit: Self.recentDayCount)
        streak = StreakService.compute(context: context)
        latestRecap = Self.latestRecap(log: log, names: nutrientsByID.mapValues(\.name), now: now)
    }

    /// Every nutrient, entry and exclusion as a `HistoryLog`, with the nutrients in display order (also used by the
    /// weekly recap and its notification). `from` limits entries and exclusions to that day on, for a single week's
    /// recap on the logging path (the notification, Today's card).
    static func loadLog(context: ModelContext, now: Date = .now, from: Date? = nil) -> (HistoryLog, [Nutrient]) {
        let calendar = Calendar.current
        let nutrients = orderedNutrients(context: context)
        let start = from.map { calendar.startOfDay(for: $0) } ?? .distantPast

        let records = (try? context.fetch(FetchDescriptor<IntakeRecord>(predicate: #Predicate { $0.date >= start }))) ?? []
        var totals: [Date: [UUID: Double]] = [:]
        for record in records {
            guard let nutrient = record.nutrient else { continue }
            totals[calendar.startOfDay(for: record.date), default: [:]][nutrient.id, default: 0] += record.amount
        }

        let exclusions = (try? context.fetch(FetchDescriptor<Exclusion>(predicate: #Predicate { $0.date >= start }))) ?? []
        var excluded: [Date: Set<UUID>] = [:]
        for exclusion in exclusions {
            guard let nutrient = exclusion.nutrient else { continue }
            excluded[calendar.startOfDay(for: exclusion.date), default: []].insert(nutrient.id)
        }

        let log = HistoryLog(
            nutrients: nutrients.map {
                HistoryNutrient(id: $0.id, goalType: $0.goalType, target: $0.dailyTarget, upperBound: $0.upperBound,
                                createdAt: $0.createdAt, isDeleted: $0.isDeleted, endDate: $0.endDate,
                                courseGaps: $0.courseGaps)
            },
            totals: totals, exclusions: excluded, today: now, calendar: calendar
        )
        return (log, nutrients)
    }

    func nutrient(_ id: UUID) -> Nutrient? { nutrientsByID[id] }

    /// The newest weekly recap with something in it, within the recap screen's eight weeks (nutrx Pro).
    static func latestRecap(log: HistoryLog, names: [UUID: String], now: Date) -> WeeklyRecap? {
        let newest = WeeklyRecap.latestWeek(at: now, calendar: log.calendar)
        for back in 0..<RecapViewModel.weekCount {
            let week = log.calendar.date(byAdding: .day, value: -7 * back, to: newest)!
            let recap = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: false)
            if recap.hasData { return recap }
        }
        return nil
    }

    func day(_ date: Date) -> HistoryDay? { log?.day(date) }

    // MARK: - Month

    var canShowPreviousMonth: Bool {
        guard let first = log?.firstDay else { return false }
        return month.month > first
    }

    /// Up to the month holding "today" as of the last refresh — the same today the calendar rings.
    var canShowNextMonth: Bool {
        guard let today = log?.today else { return false }
        return !month.contains(today)
    }

    func showPreviousMonth() {
        if canShowPreviousMonth { month = month.moved(by: -1) }
    }

    func showNextMonth() {
        if canShowNextMonth { month = month.moved(by: 1) }
    }

    // MARK: - Entries

    /// A nutrient's records on one day, oldest first.
    func intakeRecords(for nutrient: Nutrient, on day: Date, context: ModelContext) -> [IntakeRecord] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let nutrientID = nutrient.id
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID && $0.date >= start && $0.date < end
            },
            sortBy: [SortDescriptor(\IntakeRecord.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// All nutrients, deleted ones included, in Today's order: group, then position within the group.
    static func orderedNutrients(context: ModelContext) -> [Nutrient] {
        let nutrients = (try? context.fetch(FetchDescriptor<Nutrient>())) ?? []
        let groups = (try? context.fetch(FetchDescriptor<NutrientGroup>())) ?? []
        // Nutrients without a group belong to General.
        let generalOrder = groups.first(where: \.isSystem)?.sortOrder ?? Int.max
        return nutrients.sorted { lhs, rhs in
            let lhsGroup = lhs.group?.sortOrder ?? generalOrder
            let rhsGroup = rhs.group?.sortOrder ?? generalOrder
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
            if lhs.groupSortOrder != rhs.groupSortOrder { return lhs.groupSortOrder < rhs.groupSortOrder }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
}
