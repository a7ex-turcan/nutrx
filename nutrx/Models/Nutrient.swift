import Foundation
import SwiftData

enum GoalType: String, Codable, CaseIterable {
    case minimum   // hit at least X — default, matches legacy behaviour
    case maximum   // stay under X
    case range     // stay between dailyTarget (lower) and upperBound (upper)
}

@Model
final class Nutrient {
    var id: UUID = UUID()
    var name: String = ""
    var unit: String = ""
    var step: Double = 1
    var dailyTarget: Double = 0
    var sortOrder: Int = 0
    var isDeleted: Bool = false
    var notes: String? = nil
    var group: NutrientGroup? = nil
    var groupSortOrder: Int = 0
    var createdAt: Date = Date()
    var goalTypeRaw: String = GoalType.minimum.rawValue
    var upperBound: Double? = nil
    var tintRaw: String = ""  // "" = never chosen; `tint` falls back to an id-derived tint
    var symbolName: String = "pills"

    // Supply & refills (nutrx Pro, docs/pro/PLAN.md phase 4). `supplyServings == nil` means supply isn't set.
    /// Units in one serving (one softgel = 1,000 IU); nil means one step ("each tap adds").
    var servingAmount: Double? = nil
    /// Servings in the bottle when it was last refilled.
    var supplyServings: Double? = nil
    /// When the bottle was last refilled; what's logged since then comes out of it.
    var supplyRefilledAt: Date? = nil
    /// Remind when this many days are left.
    var refillReminderDays: Int = 7

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .minimum }
        set { goalTypeRaw = newValue.rawValue }
    }

    var tint: NutrientTint {
        get { NutrientTint(rawValue: tintRaw) ?? .fallback(for: id) }
        set { tintRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \IntakeRecord.nutrient)
    var intakeRecords: [IntakeRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \Exclusion.nutrient)
    var exclusions: [Exclusion]? = []

    @Relationship(deleteRule: .cascade, inverse: \NutrientReminder.nutrient)
    var reminders: [NutrientReminder]? = []

    /// The stacks this nutrient is in. A deleted (soft-deleted) nutrient keeps its entries, but stacks skip it.
    @Relationship(deleteRule: .cascade, inverse: \LogStackEntry.nutrient)
    var stackEntries: [LogStackEntry]? = []

    init(name: String, unit: String, step: Double, dailyTarget: Double, sortOrder: Int, isDeleted: Bool = false, goalType: GoalType = .minimum, upperBound: Double? = nil) {
        self.name = name
        self.unit = unit
        self.step = step
        self.dailyTarget = dailyTarget
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
        self.goalTypeRaw = goalType.rawValue
        self.upperBound = upperBound
    }
}
