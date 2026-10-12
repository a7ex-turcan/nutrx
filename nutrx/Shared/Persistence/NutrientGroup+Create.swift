import Foundation
import SwiftData

extension NutrientGroup {
    /// Inserts a new user group after the existing ones (the system "General" group stays last).
    /// Returns nil for a blank name.
    @discardableResult
    static func create(named name: String, among groups: [NutrientGroup], in context: ModelContext) -> NutrientGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let nextOrder = (groups.filter { !$0.isSystem }.map(\.sortOrder).max() ?? -1) + 1
        let group = NutrientGroup(name: trimmed, sortOrder: nextOrder)
        context.insert(group)
        return group
    }
}
