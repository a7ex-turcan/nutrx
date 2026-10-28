import Foundation
import SwiftData

@Observable
final class TodayViewModel {
    struct NutrientIntake {
        let nutrient: Nutrient
        /// Raw sum of today's records — can dip below 0 if an entry was deleted while a decrement remains.
        /// Display goes through `progress`, which floors at 0.
        let total: Double
        /// Under a weekly schedule (#132): the week's counted days before today, and its count.
        var weekBefore: NutrientSchedule.WeekProgress? = nil

        var progress: GoalProgress { GoalProgress(nutrient: nutrient, current: total) }

        /// A goal of the day: a weekly one (#132) only once it's met today. The day score and the group chips both
        /// count through this, so they can't disagree.
        var isGoalToday: Bool { weekBefore == nil || progress.countsAsMet }

        /// "2 of 3 this week", today included once its goal is met.
        var weekly: NutrientSchedule.WeekProgress? {
            weekBefore.map { week in
                NutrientSchedule.WeekProgress(met: min(week.times, week.met + (progress.countsAsMet ? 1 : 0)),
                                              times: week.times)
            }
        }
    }

    struct GroupSection: Identifiable {
        let id: PersistentIdentifier
        let group: NutrientGroup
        var intakes: [NutrientIntake]
    }

    private(set) var nutrientIntakes: [(nutrient: Nutrient, total: Double)] = []
    /// Supply (nutrx Pro): each supply-tracked nutrient's logs since the earlier of its refill and the 14-day
    /// window — all `SupplySchedule` needs — fetched once per refresh and kept current by `updateTotal`.
    private(set) var supplyLogs: [PersistentIdentifier: [SupplySchedule.Log]] = [:]
    private(set) var groupSections: [GroupSection] = []

    /// A running nutrient that isn't due today (schedules, #132), for Today's collapsed Not today section.
    struct NotTodayItem: Identifiable {
        let nutrient: Nutrient
        /// Anything logged today anyway; it's kept, but doesn't count.
        var total: Double
        /// The next day it's due; nil when its course is over first.
        let nextDue: Date?
        /// A weekly schedule whose count was reached this week: due again on Monday.
        var isWeekDone = false

        var id: PersistentIdentifier { nutrient.persistentModelID }
    }

    /// Running but off today, in Today's order (groups, then within each group).
    private(set) var notToday: [NotTodayItem] = []

    /// Anything running at all, due today or not: Today's empty state is only for when there's nothing.
    var hasRunningNutrients: Bool { !groupSections.isEmpty || !notToday.isEmpty }

    /// Met vs. total across every nutrient shown today (collapsed groups included). A weekly one (#132) counts only
    /// once met today: until then it's on Today but not a goal of the day.
    var dayScore: DayScore {
        let intakes = groupSections.flatMap(\.intakes)
        return DayScore(progresses: intakes.filter(\.isGoalToday).map(\.progress),
                        weeklyShown: intakes.filter { !$0.isGoalToday }.count)
    }

    /// The next reminder still to come today: a shown nutrient's reminder, unless that nutrient is already
    /// logged today. The same rule and the same times `NotificationService.refreshAllNutrientReminders` schedules
    /// by (#4): a nutrient at its usual time (#137) names the time that fires, its weekend one on a weekend. A
    /// stack's reminder too ("Morning stack"), while something in it is due and it isn't done.
    func nextReminder(after now: Date = .now, stacks: [LogStack] = []) -> UpcomingReminder? {
        let calendar = Calendar.current
        func dates(_ planned: (times: [ReminderSchedule.Time], weekend: [ReminderSchedule.Time]?)) -> [Date] {
            (calendar.isDateInWeekend(now) ? planned.weekend ?? planned.times : planned.times).compactMap {
                calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: now)
            }
        }
        let stackCandidates = !UsualTime.isAvailable ? [] : stacks.filter { $0.reminderMinutes >= 0 }.flatMap { stack in
            let due = StackLogging.dueEntries(of: stack, now: now).compactMap(\.nutrient)
            guard !due.isEmpty, !StackLogging.isLoggedToday(stack, now: now),
                  !due.allSatisfy({ total(for: $0) > 0 }) else { return [(nutrientName: String, timeOfDay: Date)]() }
            return dates(NotificationService.reminderTimes(for: stack, now: now)).map {
                (nutrientName: StackReminderText.fullName(stack.name), timeOfDay: $0)
            }
        }
        let candidates = stackCandidates + groupSections
            .flatMap(\.intakes)
            .filter { $0.total <= 0 }
            .flatMap { intake in
                dates(NotificationService.reminderTimes(for: intake.nutrient, now: now)).map {
                    (nutrientName: intake.nutrient.name, timeOfDay: $0)
                }
            }
        return UpcomingReminder.next(after: now, among: candidates)
    }

    /// Today's total for a nutrient, as shown on its card or in Not today (0 for one that isn't on Today).
    func total(for nutrient: Nutrient) -> Double {
        let id = nutrient.persistentModelID
        return nutrientIntakes.first { $0.nutrient.persistentModelID == id }?.total
            ?? notToday.first { $0.id == id }?.total ?? 0
    }

    /// Logs a stack (with any amounts changed for this time) and does a + tap's follow-ups. Returns what was logged
    /// so the sheet can show it and undo it, and whether any of it met a goal (for the haptic).
    @discardableResult
    func logStack(_ stack: LogStack, amounts: [PersistentIdentifier: Double],
                  context: ModelContext) -> (logged: StackLogging.Logged, reachedGoal: Bool) {
        let reachedGoal = StackLogging.dueEntries(of: stack).contains { entry in
            guard let nutrient = entry.nutrient else { return false }
            let amount = amounts[entry.persistentModelID] ?? entry.amount
            return GoalProgress(nutrient: nutrient, current: total(for: nutrient)).reachesGoal(adding: amount)
        }
        let logged = StackLogging.log(stack, amounts: amounts, context: context)
        afterStackChange(context: context)
        return (logged, reachedGoal)
    }

    func undoStack(_ logged: StackLogging.Logged, of stack: LogStack, context: ModelContext) {
        StackLogging.undo(logged, of: stack, context: context)
        afterStackChange(context: context)
    }

    private func afterStackChange(context: ModelContext) {
        refresh(context: context)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetReload.all()
    }

    /// A nutrient's supply status from the cached logs, or nil when supply isn't set.
    func supplyStatus(for nutrient: Nutrient, now: Date = .now) -> SupplySchedule.Status? {
        guard let setup = nutrient.supplySetup else { return nil }
        return SupplySchedule.status(setup: setup, logs: supplyLogs[nutrient.persistentModelID] ?? [], now: now)
    }

    /// One fetch for every supply-tracked nutrient, bounded by the earliest date any of them needs.
    private func refreshSupplyLogs(nutrients: [Nutrient], context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -(SupplySchedule.historyWindowDays - 1),
                                        to: calendar.startOfDay(for: now)) ?? now
        let tracked = nutrients.compactMap { nutrient in nutrient.supplySetup.map { (nutrient, $0) } }
        guard let earliest = tracked.map({ min($0.1.refilledAt, windowStart) }).min() else {
            supplyLogs = [:]
            return
        }
        let descriptor = FetchDescriptor<IntakeRecord>(predicate: #Predicate { $0.date >= earliest })
        let records = (try? context.fetch(descriptor)) ?? []
        var byNutrient: [PersistentIdentifier: [SupplySchedule.Log]] = [:]
        for record in records {
            guard let id = record.nutrient?.persistentModelID else { continue }
            byNutrient[id, default: []].append(SupplySchedule.Log(date: record.date, amount: record.amount))
        }
        supplyLogs = Dictionary(uniqueKeysWithValues: tracked.map { ($0.0.persistentModelID, byNutrient[$0.0.persistentModelID] ?? []) })
    }

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients, without those whose course has ended (#99). Those not due today (#132) go to
        // Not today.
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isRemoved },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let fetched = try? context.fetch(nutrientDescriptor) else { return }
        let running = fetched.filter { $0.isRunning(on: startOfDay) }
        // Decided once per refresh: a weekly schedule reads its week from its logs.
        let nutrients = running.filter { $0.isDue(on: startOfDay) }
        let dueIDs = Set(nutrients.map(\.persistentModelID))

        // Fetch all groups
        let groupDescriptor = FetchDescriptor<NutrientGroup>(
            sortBy: [SortDescriptor(\NutrientGroup.sortOrder)]
        )
        let allGroups = (try? context.fetch(groupDescriptor)) ?? []
        let generalGroup = allGroups.first(where: { $0.isSystem })

        // Fetch today's exclusions
        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []
        let excludedNutrientIDs = Set(exclusions.compactMap { $0.nutrient?.persistentModelID })

        // Fetch today's intake records
        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let records = (try? context.fetch(intakeDescriptor)) ?? []

        // Group intake by nutrient
        var totalsByID: [PersistentIdentifier: Double] = [:]
        for record in records {
            if let id = record.nutrient?.persistentModelID {
                totalsByID[id, default: 0] += record.amount
            }
        }

        // Build flat list (kept for backward compat with decrement lookup)
        let activeNutrients = nutrients.filter { !excludedNutrientIDs.contains($0.persistentModelID) }
        refreshSupplyLogs(nutrients: activeNutrients, context: context)
        nutrientIntakes = activeNutrients.map { nutrient in
            (nutrient: nutrient, total: totalsByID[nutrient.persistentModelID] ?? 0)
        }

        // Build grouped sections
        var sectionsByGroupID: [PersistentIdentifier: [NutrientIntake]] = [:]
        for nutrient in activeNutrients {
            let groupID = (nutrient.group ?? generalGroup)?.persistentModelID ?? generalGroup?.persistentModelID
            guard let gid = groupID else { continue }
            let total = totalsByID[nutrient.persistentModelID] ?? 0
            sectionsByGroupID[gid, default: []].append(NutrientIntake(nutrient: nutrient, total: total,
                                                                      weekBefore: nutrient.weekProgress(before: startOfDay)))
        }

        // Sort intakes within each group by groupSortOrder, then sortOrder as tiebreaker
        for key in sectionsByGroupID.keys {
            sectionsByGroupID[key]?.sort {
                if $0.nutrient.groupSortOrder != $1.nutrient.groupSortOrder {
                    return $0.nutrient.groupSortOrder < $1.nutrient.groupSortOrder
                }
                return $0.nutrient.sortOrder < $1.nutrient.sortOrder
            }
        }

        // Build sections in group sort order, only include groups that have nutrients
        groupSections = allGroups.compactMap { group in
            guard let intakes = sectionsByGroupID[group.persistentModelID], !intakes.isEmpty else { return nil }
            return GroupSection(id: group.persistentModelID, group: group, intakes: intakes)
        }

        // Not today, in the same order: by group, then within it
        let groupOrder = Dictionary(allGroups.enumerated().map { ($1.persistentModelID, $0) },
                                    uniquingKeysWith: { first, _ in first })
        func groupIndex(_ nutrient: Nutrient) -> Int {
            (nutrient.group ?? generalGroup).flatMap { groupOrder[$0.persistentModelID] } ?? Int.max
        }
        notToday = running.filter { !dueIDs.contains($0.persistentModelID) }
            .sorted {
                (groupIndex($0), $0.groupSortOrder, $0.sortOrder) < (groupIndex($1), $1.groupSortOrder, $1.sortOrder)
            }
            .map { nutrient in
                let isWeekDone = nutrient.weekProgress(before: startOfDay)?.isDone == true
                // A done week is back on Monday, unless its course is over by then; otherwise the next dose day.
                let nextDue = isWeekDone
                    ? Calendar.current.date(byAdding: .day, value: 7, to: NutrientSchedule.weekStart(of: startOfDay))
                        .flatMap { nutrient.hasEnded(by: $0) ? nil : $0 }
                    : nutrient.nextDueDay(after: startOfDay)
                return NotTodayItem(nutrient: nutrient, total: totalsByID[nutrient.persistentModelID] ?? 0,
                                    nextDue: nextDue, isWeekDone: isWeekDone)
            }
    }

    func increment(_ nutrient: Nutrient, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: nutrient.step)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetReload.all()
    }

    func addCustomAmount(_ amount: Double, to nutrient: Nutrient, note: String? = nil, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: amount, note: note)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: amount)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetReload.all()
    }

    func decrement(_ nutrient: Nutrient, context: ModelContext) {
        if let entry = nutrientIntakes.first(where: { $0.nutrient.persistentModelID == nutrient.persistentModelID }) {
            let newTotal = entry.total - nutrient.step
            if newTotal >= 0 {
                let record = IntakeRecord(nutrient: nutrient, amount: -nutrient.step)
                context.insert(record)
                try? context.save()
                updateTotal(for: nutrient, delta: -nutrient.step)
                NotificationService.refreshDailyReminder(context: context)
                // Back to zero today: its remaining reminders today come back.
                NotificationService.refreshAllNutrientReminders(context: context)
                WidgetReload.all()
            }
        }
    }

    /// Deletes one logged entry (from the log sheet). No confirmation — the sheet deletes immediately.
    func deleteRecord(_ record: IntakeRecord, context: ModelContext) {
        guard let nutrient = record.nutrient else { return }
        let amount = record.amount
        let date = record.date
        context.delete(record)
        try? context.save()
        updateTotal(for: nutrient, delta: -amount, at: date)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetReload.all()
    }

    /// Brings the pending reminders in line with today's logs and the rolling window (call on foreground).
    func rescheduleReminders(context: ModelContext) {
        NotificationService.refreshAllNutrientReminders(context: context)
    }

    // MARK: - In-place total update (avoids re-fetch reordering)

    /// `at` is when the change counts for supply: now for a + or −, the entry's own date for a deleted entry (so
    /// deleting a dose from before a same-day refill doesn't eat into the new bottle).
    private func updateTotal(for nutrient: Nutrient, delta: Double, at date: Date = .now) {
        let id = nutrient.persistentModelID
        if supplyLogs[id] != nil {
            supplyLogs[id]?.append(SupplySchedule.Log(date: date, amount: delta))
        }

        // Not today: an off-day log is kept, so the log sheet shows it
        if let idx = notToday.firstIndex(where: { $0.id == id }) {
            notToday[idx].total += delta
        }

        // Update flat list
        if let idx = nutrientIntakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
            let old = nutrientIntakes[idx]
            nutrientIntakes[idx] = (nutrient: old.nutrient, total: old.total + delta)
        }

        // Update grouped sections
        for sIdx in groupSections.indices {
            if let iIdx = groupSections[sIdx].intakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
                let old = groupSections[sIdx].intakes[iIdx]
                groupSections[sIdx].intakes[iIdx] = NutrientIntake(nutrient: old.nutrient, total: old.total + delta,
                                                                   weekBefore: old.weekBefore)
                return
            }
        }
    }
}
