import Foundation
import SwiftData
import WidgetKit

@Observable
final class TodayViewModel {
    struct NutrientIntake {
        let nutrient: Nutrient
        let total: Double
    }

    struct GroupSection: Identifiable {
        let id: PersistentIdentifier
        let group: NutrientGroup
        var intakes: [NutrientIntake]
    }

    private(set) var nutrientIntakes: [(nutrient: Nutrient, total: Double)] = []
    private(set) var groupSections: [GroupSection] = []

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

        // Sort intakes within each group by groupSortOrder
        for key in sectionsByGroupID.keys {
            sectionsByGroupID[key]?.sort { $0.nutrient.groupSortOrder < $1.nutrient.groupSortOrder }
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
        refresh(context: context)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.suppressRemindersAfterLogging(for: nutrient)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addCustomAmount(_ amount: Double, to nutrient: Nutrient, note: String? = nil, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: amount, note: note)
        context.insert(record)
        refresh(context: context)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.suppressRemindersAfterLogging(for: nutrient)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func decrement(_ nutrient: Nutrient, context: ModelContext) {
        if let entry = nutrientIntakes.first(where: { $0.nutrient.persistentModelID == nutrient.persistentModelID }) {
            let newTotal = entry.total - nutrient.step
            if newTotal >= 0 {
                let record = IntakeRecord(nutrient: nutrient, amount: -nutrient.step)
                context.insert(record)
                refresh(context: context)
                NotificationService.refreshDailyReminder(context: context)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
