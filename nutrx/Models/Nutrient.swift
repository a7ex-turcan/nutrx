import Foundation
import SwiftData

@Model
final class Nutrient {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var unit: String
    var step: Double
    var dailyTarget: Double
    var sortOrder: Int
    var isDeleted: Bool
    var notes: String? = nil
    var group: NutrientGroup? = nil
    var groupSortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \IntakeRecord.nutrient)
    var intakeRecords: [IntakeRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \Exclusion.nutrient)
    var exclusions: [Exclusion] = []

    @Relationship(deleteRule: .cascade, inverse: \NutrientReminder.nutrient)
    var reminders: [NutrientReminder] = []

    init(name: String, unit: String, step: Double, dailyTarget: Double, sortOrder: Int, isDeleted: Bool = false) {
        self.name = name
        self.unit = unit
        self.step = step
        self.dailyTarget = dailyTarget
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
    }
}
