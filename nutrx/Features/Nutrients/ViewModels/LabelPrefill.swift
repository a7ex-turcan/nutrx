import Foundation

/// Fills the new-nutrient form from a read label (nutrx Pro, docs/pro/design/4-scan-label: review). The user always
/// checks it in the normal form: nothing is created until Add. The goal is never filled — nutrx doesn't suggest
/// amounts. A known supplement gets its usual colour and symbol; otherwise the form's look stays, and so do the goal,
/// reminder times, stacks and notes the user already set (Scan again doesn't wipe them).
enum LabelPrefill {
    static func apply(_ label: SupplementLabel, to draft: NutrientDraft) {
        let (tint, symbol, reminders, notes) = (draft.tint, draft.symbolName, draft.pendingReminderTimes, draft.notes)
        let (goalType, target, upper) = (draft.goalType, draft.dailyTarget, draft.upperBound)
        let (stacks, added) = (draft.pendingStacks, draft.addedFromLabel)
        draft.reset()
        (draft.pendingStacks, draft.addedFromLabel) = (stacks, added)
        (draft.tint, draft.symbolName, draft.pendingReminderTimes, draft.notes) = (tint, symbol, reminders, notes)
        (draft.goalType, draft.dailyTarget, draft.upperBound) = (goalType, target, upper)
        var read: Set<NutrientDraft.ScannedField> = []
        if let name = label.name {
            draft.name = name
            read.insert(.name)
            if let known = StartingPoint.all.first(where: { name.localizedCaseInsensitiveContains($0.name) }) {
                draft.tint = known.tint
                draft.symbolName = known.symbolName
            }
        }
        if let unit = label.unit {
            draft.unit = unit
            read.insert(.unit)
        }
        if let amount = label.amountPerServing {
            draft.step = NutrientDraft.editableText(amount)
            read.insert(.step)
        }
        if let servings = label.servingsPerContainer {
            draft.supplyServings = String(servings)
            read.insert(.supply)
        }
        draft.servingForm = label.servingForm
        draft.labelIngredients = label.ingredients
        draft.labelIngredientName = label.name
        draft.markScanned(read: read)
    }

    // MARK: - Several ingredients on one label

    /// The label's other ingredients, for "Also on this label": not the one the form has now, nor ones already added.
    static func otherIngredients(on draft: NutrientDraft) -> [LabelIngredient] {
        let current = draft.labelIngredientName ?? draft.name
        let taken = Set((draft.addedFromLabel + [current]).map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        var seen = Set<String>()
        return draft.labelIngredients.filter { ingredient in
            let key = ingredient.name.lowercased()
            return !taken.contains(key) && seen.insert(key).inserted
        }
    }

    /// Switches the form to another ingredient of the same label: its name, unit and amount, marked "from label";
    /// the bottle's servings, the goal and everything else the user set stay.
    static func switchTo(_ ingredient: LabelIngredient, on draft: NutrientDraft) {
        draft.name = ingredient.name
        draft.labelIngredientName = ingredient.name
        draft.unit = ingredient.unit
        draft.step = NutrientDraft.editableText(ingredient.amount)
        if let known = StartingPoint.all.first(where: { ingredient.name.localizedCaseInsensitiveContains($0.name) }) {
            draft.tint = known.tint
            draft.symbolName = known.symbolName
        }
        // Only these three change; the bottle's servings keep whatever state they had.
        draft.scannedFields.formUnion([.name, .unit, .step])
        draft.unreadFields.subtract([.name, .unit, .step])
    }

    /// After adding one nutrient from a label, the form starts on the next ingredient: a new nutrient (no goal,
    /// reminders or notes yet) from the same bottle, in the same stacks.
    static func startNext(_ ingredient: LabelIngredient, on draft: NutrientDraft) {
        let added = draft.addedFromLabel + [draft.labelIngredientName ?? draft.name]
        let (ingredients, stacks) = (draft.labelIngredients, draft.pendingStacks)
        let (servings, form, tint, symbol) = (draft.supplyServings, draft.servingForm, draft.tint, draft.symbolName)
        // The bottle size keeps its state: read from the label, typed by the user, or still to fill in.
        let (supplyRead, supplyUnread) = (draft.scannedFields.contains(.supply), draft.unreadFields.contains(.supply))
        draft.reset()
        (draft.tint, draft.symbolName) = (tint, symbol)
        (draft.labelIngredients, draft.addedFromLabel, draft.pendingStacks) = (ingredients, added, stacks)
        (draft.supplyServings, draft.servingForm) = (servings, form)
        draft.markScanned(read: supplyRead ? [.supply] : [])
        if !supplyRead && !supplyUnread { draft.unreadFields.remove(.supply) }
        switchTo(ingredient, on: draft)
    }

    /// The review banner: "Filled from the label. Check it before adding." / "One field needs you." / "Two fields
    /// need you."
    static func bannerText(unread: Int) -> String {
        switch unread {
        case 0: "Filled from the label. Check it before adding."
        case 1: "Filled from the label. One field needs you."
        case 2: "Filled from the label. Two fields need you."
        case 3: "Filled from the label. Three fields need you."
        default: "Couldn't read much from the label. Fill in the rest below."
        }
    }

    /// The hint under a field the scan couldn't read.
    static func unreadHint(_ field: NutrientDraft.ScannedField) -> String {
        switch field {
        case .name: "Couldn't read the name — type what's on the front of the bottle."
        case .unit: "Couldn't read the unit — it's next to the amount, like mg or IU."
        case .step: "Couldn't read the amount — it's under “amount per serving”."
        case .supply: "Couldn't read the bottle size — it's usually “servings per container”."
        }
    }
}
