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
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        nutrient.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

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
}
