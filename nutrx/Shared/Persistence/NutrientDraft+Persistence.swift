import Foundation
import SwiftData

extension NutrientDraft {
    /// Inserts a new nutrient built from this draft, with its pending reminders and stacks, at the end of `group`.
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
        nutrient.endDate = endDate
        // A schedule (#132) from today; every day stores nothing.
        nutrient.scheduleRaw = NutrientSchedule().setting(scheduleKind, from: .now).encode()

        if let group {
            nutrient.group = group
            nutrient.groupSortOrder = ((group.nutrients ?? []).map(\.groupSortOrder).max() ?? -1) + 1
        }

        context.insert(nutrient)

        // A bottle size from a scanned label starts supply tracking from today (nutrx Pro).
        if let servings = supplyServings.parsedDouble, servings > 0 {
            nutrient.supplyServings = servings.rounded()
            nutrient.supplyRefilledAt = .now
        }

        for time in pendingReminderTimes {
            context.insert(NutrientReminder(nutrient: nutrient, timeOfDay: time))
        }
        if !pendingReminderTimes.isEmpty {
            NotificationService.refreshAllNutrientReminders(context: context)
        }
        // The stacks picked in the form, new ones created now (so a cancelled form leaves none behind).
        if StackLogging.add(nutrient, toStacks: pendingStacks, context: context) {
            StackShortcutLogging.stacksChanged()
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
        // Through setCourse, so a new duration on an ended course keeps the days since it ended as a gap.
        nutrient.setCourse(endDate: endDate)
        // A changed schedule (#132) applies from today on; the days before keep the one they had.
        nutrient.scheduleRaw = nutrient.schedule().setting(scheduleKind, from: .now).encode()
        // Pending reminders carry the name and notes, and stop after a course's last day; re-adding them picks up
        // the edit.
        if !(nutrient.reminders ?? []).isEmpty, let context = nutrient.modelContext {
            NotificationService.refreshAllNutrientReminders(context: context)
        }
    }

    private var trimmedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
