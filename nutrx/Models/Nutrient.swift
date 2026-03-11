import Foundation
import SwiftData

@Model
final class Nutrient: @unchecked Sendable {
    var name: String
    var unit: String
    var step: Double
    var dailyTarget: Double
    var sortOrder: Int
    var isDeleted: Bool

    @Relationship(deleteRule: .cascade, inverse: \IntakeRecord.nutrient)
    var intakeRecords: [IntakeRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \Exclusion.nutrient)
    var exclusions: [Exclusion] = []

    init(name: String, unit: String, step: Double, dailyTarget: Double, sortOrder: Int, isDeleted: Bool = false) {
        self.name = name
        self.unit = unit
        self.step = step
        self.dailyTarget = dailyTarget
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
    }
}
