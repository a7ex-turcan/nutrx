import Foundation
import SwiftData
import WidgetKit

@Observable
final class TodayViewModel {
    struct NutrientIntake {
        let nutrient: Nutrient
        /// Raw sum of today's records — can dip below 0 if an entry was deleted while a decrement remains.
        /// Display goes through `progress`, which floors at 0.
        let total: Double

        var progress: GoalProgress { GoalProgress(nutrient: nutrient, current: total) }
    }

    struct GroupSection: Identifiable {
        let id: PersistentIdentifier
        let group: NutrientGroup
        var intakes: [NutrientIntake]
    }

    private(set) var nutrientIntakes: [(nutrient: Nutrient, total: Double)] = []
    private(set) var groupSections: [GroupSection] = []

    /// Met vs. total across every nutrient shown today (collapsed groups included).
    var dayScore: DayScore {
        DayScore(progresses: groupSections.flatMap(\.intakes).map(\.progress))
    }

    /// The next reminder still to come today: a shown nutrient's reminder, unless that nutrient is already
    /// logged today. The same rule `NotificationService.refreshAllNutrientReminders` schedules by (#4).
    func nextReminder(after now: Date = .now) -> UpcomingReminder? {
        let candidates = groupSections
            .flatMap(\.intakes)
            .filter { $0.total <= 0 }
            .flatMap { intake in
                (intake.nutrient.reminders ?? []).map { (nutrientName: intake.nutrient.name, timeOfDay: $0.timeOfDay) }
            }
        return UpcomingReminder.next(after: now, among: candidates)
    }

    /// Today's total for a nutrient, as shown on its card (0 for one that isn't on Today).
    func total(for nutrient: Nutrient) -> Double {
        nutrientIntakes.first { $0.nutrient.persistentModelID == nutrient.persistentModelID }?.total ?? 0
    }

    /// Logs a stack (with any amounts changed for this time) and does a + tap's follow-ups. Returns what was logged
    /// so the sheet can show it and undo it, and whether any of it met a goal (for the haptic).
    @discardableResult
    func logStack(_ stack: LogStack, amounts: [PersistentIdentifier: Double],
                  context: ModelContext) -> (logged: StackLogging.Logged, reachedGoal: Bool) {
        let reachedGoal = StackLogging.activeEntries(of: stack).contains { entry in
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let nutrients = try? context.fetch(nutrientDescriptor) else { return }

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
        nutrientIntakes = activeNutrients.map { nutrient in
            (nutrient: nutrient, total: totalsByID[nutrient.persistentModelID] ?? 0)
        }

        // Build grouped sections
        var sectionsByGroupID: [PersistentIdentifier: [NutrientIntake]] = [:]
        for nutrient in activeNutrients {
            let groupID = (nutrient.group ?? generalGroup)?.persistentModelID ?? generalGroup?.persistentModelID
            guard let gid = groupID else { continue }
            let total = totalsByID[nutrient.persistentModelID] ?? 0
            sectionsByGroupID[gid, default: []].append(NutrientIntake(nutrient: nutrient, total: total))
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
    }

    func increment(_ nutrient: Nutrient, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: nutrient.step)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addCustomAmount(_ amount: Double, to nutrient: Nutrient, note: String? = nil, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: amount, note: note)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: amount)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetCenter.shared.reloadAllTimelines()
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
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Deletes one logged entry (from the log sheet). No confirmation — the sheet deletes immediately.
    func deleteRecord(_ record: IntakeRecord, context: ModelContext) {
        guard let nutrient = record.nutrient else { return }
        let amount = record.amount
        context.delete(record)
        try? context.save()
        updateTotal(for: nutrient, delta: -amount)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Brings the pending reminders in line with today's logs and the rolling window (call on foreground).
    func rescheduleReminders(context: ModelContext) {
        NotificationService.refreshAllNutrientReminders(context: context)
    }

    // MARK: - In-place total update (avoids re-fetch reordering)

    private func updateTotal(for nutrient: Nutrient, delta: Double) {
        let id = nutrient.persistentModelID

        // Update flat list
        if let idx = nutrientIntakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
            let old = nutrientIntakes[idx]
            nutrientIntakes[idx] = (nutrient: old.nutrient, total: old.total + delta)
        }

        // Update grouped sections
        for sIdx in groupSections.indices {
            if let iIdx = groupSections[sIdx].intakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
                let old = groupSections[sIdx].intakes[iIdx]
                groupSections[sIdx].intakes[iIdx] = NutrientIntake(nutrient: old.nutrient, total: old.total + delta)
                return
            }
        }
    }
}
