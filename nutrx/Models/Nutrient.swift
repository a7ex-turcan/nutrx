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

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .minimum }
        set { goalTypeRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \IntakeRecord.nutrient)
    var intakeRecords: [IntakeRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \Exclusion.nutrient)
    var exclusions: [Exclusion]? = []

    @Relationship(deleteRule: .cascade, inverse: \NutrientReminder.nutrient)
    var reminders: [NutrientReminder]? = []

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
