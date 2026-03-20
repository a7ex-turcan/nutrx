import Foundation
import SwiftData

@Observable
final class TodayViewModel {
    private(set) var nutrientIntakes: [(nutrient: Nutrient, total: Double)] = []

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients
        var nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let nutrients = try? context.fetch(nutrientDescriptor) else { return }

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

        // Build the display list, excluding excluded nutrients
        nutrientIntakes = nutrients
            .filter { !excludedNutrientIDs.contains($0.persistentModelID) }
            .map { nutrient in
                let total = max(0, totalsByID[nutrient.persistentModelID] ?? 0)
                return (nutrient: nutrient, total: total)
            }
    }

    func increment(_ nutrient: Nutrient, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        refresh(context: context)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.suppressRemindersAfterLogging(for: nutrient)
    }

    func addCustomAmount(_ amount: Double, to nutrient: Nutrient, note: String? = nil, context: ModelContext) {
        let record = IntakeRecord(nutrient: nutrient, amount: amount, note: note)
        context.insert(record)
        refresh(context: context)
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.suppressRemindersAfterLogging(for: nutrient)
    }

    func decrement(_ nutrient: Nutrient, context: ModelContext) {
        // Find current total for today
        if let entry = nutrientIntakes.first(where: { $0.nutrient.persistentModelID == nutrient.persistentModelID }) {
            let newTotal = entry.total - nutrient.step
            // Only decrement if result stays >= 0
            if newTotal >= 0 {
                let record = IntakeRecord(nutrient: nutrient, amount: -nutrient.step)
                context.insert(record)
                refresh(context: context)
                NotificationService.refreshDailyReminder(context: context)
            }
        }
    }
}
