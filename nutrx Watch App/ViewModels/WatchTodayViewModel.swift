import Foundation
import SwiftData
import WidgetKit

@Observable
final class WatchTodayViewModel {
    struct GroupSection: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let intakes: [(nutrient: Nutrient, total: Double)]
    }

    private(set) var sections: [GroupSection] = []
    private(set) var hasCustomGroups = false

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let nutrients = try? context.fetch(nutrientDescriptor) else { return }

        // Fetch groups
        let groupDescriptor = FetchDescriptor<NutrientGroup>(sortBy: [SortDescriptor(\NutrientGroup.sortOrder)])
        let allGroups = (try? context.fetch(groupDescriptor)) ?? []
        let generalGroup = allGroups.first(where: { $0.isSystem })
        hasCustomGroups = allGroups.contains(where: { !$0.isSystem })

        // Fetch today's exclusions
        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []
        let excludedIDs = Set(exclusions.compactMap { $0.nutrient?.persistentModelID })

        // Fetch today's intake records
        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let records = (try? context.fetch(intakeDescriptor)) ?? []

        var totalsByID: [PersistentIdentifier: Double] = [:]
        for record in records {
            if let id = record.nutrient?.persistentModelID {
                totalsByID[id, default: 0] += record.amount
            }
        }

        let activeNutrients = nutrients.filter { !excludedIDs.contains($0.persistentModelID) }

        var result: [GroupSection] = []
        for group in allGroups {
            let groupNutrients = activeNutrients
                .filter { ($0.group ?? generalGroup)?.persistentModelID == group.persistentModelID }
                .sorted {
                    if $0.groupSortOrder != $1.groupSortOrder {
                        return $0.groupSortOrder < $1.groupSortOrder
                    }
                    return $0.sortOrder < $1.sortOrder
                }

            guard !groupNutrients.isEmpty else { continue }

            let intakes = groupNutrients.map { nutrient in
                (nutrient: nutrient, total: max(0, totalsByID[nutrient.persistentModelID] ?? 0))
            }
            result.append(GroupSection(id: group.persistentModelID, name: group.name, intakes: intakes))
        }

        sections = result
    }

    func increment(_ nutrient: Nutrient, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: nutrient.step)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateTotal(for nutrient: Nutrient, delta: Double) {
        let id = nutrient.persistentModelID
        for sIdx in sections.indices {
            if let nIdx = sections[sIdx].intakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
                let old = sections[sIdx].intakes[nIdx]
                var intakes = sections[sIdx].intakes
                intakes[nIdx] = (nutrient: old.nutrient, total: max(0, old.total + delta))
                sections[sIdx] = GroupSection(id: sections[sIdx].id, name: sections[sIdx].name, intakes: intakes)
                return
            }
        }
    }
}
