import Foundation
import SwiftData

extension NutrientDraft {
    /// Inserts a new nutrient built from this draft, with its pending reminders, at the end of `group`.
    /// Returns nil (and inserts nothing) if the step or target don't parse.
    @discardableResult
    func insertNutrient(into context: ModelContext, group: NutrientGroup?, sortOrder: Int) -> Nutrient? {
        guard let stepValue = step.parsedDouble,
              let targetValue = dailyTarget.parsedDouble else { return nil }

        let nutrient = Nutrient(
            name: name.trimmingCharacters(in: .whitespaces),
            unit: unit.trimmingCharacters(in: .whitespaces),
            step: stepValue,
            dailyTarget: targetValue,
            sortOrder: sortOrder,
            goalType: goalType,
            upperBound: goalType == .range ? upperBound.parsedDouble : nil
        )
        nutrient.notes = trimmedNotes
        nutrient.tint = tint
        nutrient.symbolName = symbolName

        if let group {
            nutrient.group = group
            nutrient.groupSortOrder = ((group.nutrients ?? []).map(\.groupSortOrder).max() ?? -1) + 1
        }

        context.insert(nutrient)

        for time in pendingReminderTimes {
            context.insert(NutrientReminder(nutrient: nutrient, timeOfDay: time))
        }
        if !pendingReminderTimes.isEmpty {
            NotificationService.scheduleReminders(for: nutrient)
        }
        return nutrient
    }

    /// Writes the draft's fields onto an existing nutrient (edit form). Reminders are edited separately.
    /// Does nothing if the step or target don't parse.
    func apply(to nutrient: Nutrient) {
        guard let stepValue = step.parsedDouble,
              let targetValue = dailyTarget.parsedDouble else { return }

        nutrient.name = name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
        nutrient.goalType = goalType
        nutrient.upperBound = goalType == .range ? upperBound.parsedDouble : nil
        nutrient.notes = trimmedNotes
        nutrient.tint = tint
        nutrient.symbolName = symbolName
    }

    private var trimmedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
