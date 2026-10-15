import Foundation

/// Fills the new-nutrient form from a read label (nutrx Pro, docs/pro/design/4-scan-label: review). The user always
/// checks it in the normal form: nothing is created until Add. The goal is never filled — nutrx doesn't suggest
/// amounts. A known supplement gets its usual colour and symbol; otherwise the form's look stays, and so do the goal,
/// reminder times and notes the user already set (Scan again doesn't wipe them).
enum LabelPrefill {
    static func apply(_ label: SupplementLabel, to draft: NutrientDraft) {
        let (tint, symbol, reminders, notes) = (draft.tint, draft.symbolName, draft.pendingReminderTimes, draft.notes)
        let (goalType, target, upper) = (draft.goalType, draft.dailyTarget, draft.upperBound)
        draft.reset()
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
        draft.markScanned(read: read)
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
