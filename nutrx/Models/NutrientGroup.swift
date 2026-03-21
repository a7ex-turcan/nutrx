import Foundation
import SwiftData

@Model
final class NutrientGroup {
    var name: String
    var sortOrder: Int
    var isSystem: Bool = false
    var isCollapsed: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Nutrient.group)
    var nutrients: [Nutrient] = []

    init(name: String, sortOrder: Int, isSystem: Bool = false) {
        self.name = name
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }
}
