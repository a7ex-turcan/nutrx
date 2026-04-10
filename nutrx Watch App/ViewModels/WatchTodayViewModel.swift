import Foundation
import SwiftData
import WidgetKit

@Observable
final class WatchTodayViewModel {
    private(set) var nutrientIntakes: [(nutrient: Nutrient, total: Double)] = []

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let nutrients = try? context.fetch(nutrientDescriptor) else { return }

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

        // Group intake by nutrient
        var totalsByID: [PersistentIdentifier: Double] = [:]
        for record in records {
            if let id = record.nutrient?.persistentModelID {
                totalsByID[id, default: 0] += record.amount
            }
        }

        // Build flat list, excluding excluded nutrients, sorted by groupSortOrder then sortOrder
        let activeNutrients = nutrients
            .filter { !excludedIDs.contains($0.persistentModelID) }
            .sorted {
                if $0.groupSortOrder != $1.groupSortOrder {
                    return $0.groupSortOrder < $1.groupSortOrder
                }
                return $0.sortOrder < $1.sortOrder
            }

        nutrientIntakes = activeNutrients.map { nutrient in
            let total = max(0, totalsByID[nutrient.persistentModelID] ?? 0)
            return (nutrient: nutrient, total: total)
        }
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
        if let idx = nutrientIntakes.firstIndex(where: { $0.nutrient.persistentModelID == id }) {
            let old = nutrientIntakes[idx]
            nutrientIntakes[idx] = (nutrient: old.nutrient, total: max(0, old.total + delta))
        }
    }
}
