import Foundation
import SwiftData

/// A named set of nutrients with preset amounts, logged in one go from Today ("Morning: Vitamin D 2,000 IU,
/// Omega-3 1,000 mg, Magnesium 400 mg"). Ordered by `sortOrder` on Today and in Settings → Stacks.
@Model
final class LogStack {
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    /// When the stack was last logged (from any device), so Today can show it as done for the day.
    var lastLoggedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \LogStackEntry.stack)
    var entries: [LogStackEntry]? = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
