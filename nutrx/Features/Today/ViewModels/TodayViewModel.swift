import Foundation
import SwiftData
import WidgetKit

@Observable
final class TodayViewModel {
    struct NutrientIntake {
        let nutrient: Nutrient
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
    /// Nutrients whose reminders `suppressRemindersAfterLogging` has cancelled since the last full reschedule.
    /// Mirrors the scheduler: logging here cancels a nutrient's reminders, and `rescheduleReminders`
    /// (every foreground) restores all of them — so this is not "logged today".
    private(set) var suppressedReminderIDs: Set<PersistentIdentifier> = []

    /// Met vs. total across every nutrient shown today (collapsed groups included).
    var dayScore: DayScore {
        DayScore(progresses: groupSections.flatMap(\.intakes).map(\.progress))
    }

    /// The next reminder still scheduled later today: any shown nutrient's reminder, unless logging
    /// from Today has suppressed it since the last reschedule.
    func nextReminder(after now: Date = .now) -> UpcomingReminder? {
        let candidates = groupSections
            .flatMap(\.intakes)
            .filter { !suppressedReminderIDs.contains($0.nutrient.persistentModelID) }
            .flatMap { intake in
                (intake.nutrient.reminders ?? []).map { (nutrientName: intake.nutrient.name, timeOfDay: $0.timeOfDay) }
            }
        return UpcomingReminder.next(after: now, among: candidates)
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
            let total = max(0, totalsByID[nutrient.persistentModelID] ?? 0)
            return (nutrient: nutrient, total: total)
        }

        // Build grouped sections
        var sectionsByGroupID: [PersistentIdentifier: [NutrientIntake]] = [:]
        for nutrient in activeNutrients {
            let groupID = (nutrient.group ?? generalGroup)?.persistentModelID ?? generalGroup?.persistentModelID
            guard let gid = groupID else { continue }
            let total = max(0, totalsByID[nutrient.persistentModelID] ?? 0)
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
        suppressReminders(for: nutrient)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addCustomAmount(_ amount: Double, to nutrient: Nutrient, note: String? = nil, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: amount, note: note)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: amount)
        NotificationService.refreshDailyReminder(context: context)
        suppressReminders(for: nutrient)
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
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Reschedules every nutrient's reminders (call on foreground), which also lifts today's suppressions.
    func rescheduleReminders(context: ModelContext) {
        NotificationService.refreshAllNutrientReminders(context: context)
        suppressedReminderIDs.removeAll()
    }

    private func suppressReminders(for nutrient: Nutrient) {
        NotificationService.suppressRemindersAfterLogging(for: nutrient)
        suppressedReminderIDs.insert(nutrient.persistentModelID)
    }

    // MARK: - In-place total update (avoids re-fetch reordering)

    private func updateTotal(for nutrient: Nutrient, delta: Double) {
        let id = nutrient.persistentModelID

        // Update flat list
        if let idx = nutrientIntakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
            let old = nutrientIntakes[idx]
            nutrientIntakes[idx] = (nutrient: old.nutrient, total: max(0, old.total + delta))
        }

        // Update grouped sections
        for sIdx in groupSections.indices {
            if let iIdx = groupSections[sIdx].intakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
                let old = groupSections[sIdx].intakes[iIdx]
                groupSections[sIdx].intakes[iIdx] = NutrientIntake(nutrient: old.nutrient, total: max(0, old.total + delta))
                return
            }
        }
    }
}
