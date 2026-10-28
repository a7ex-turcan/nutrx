import Foundation
import SwiftData

/// A named set of nutrients with preset amounts, logged in one go from Today ("Morning: Vitamin D 2,000 IU,
/// Omega-3 1,000 mg, Magnesium 400 mg"). Ordered by `sortOrder` on Today and in the Stacks tab.
@Model
final class LogStack {
    /// Stable id for Siri and the Shortcuts app (`StackEntity`); stacks are picked by name, never shown this.
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    /// When the stack was last logged (from any device), so Today can show it as done for the day.
    var lastLoggedAt: Date? = nil
    /// Its reminder (#137, docs/pro/REMINDERS.md §4): minutes after midnight, -1 for none. At its usual time it's
    /// the starting time, used while learning, around midnight and without Pro.
    var reminderMinutes: Int = -1
    /// At its usual time (nutrx Pro) rather than at `reminderMinutes`.
    var remindsAtUsualTime: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \LogStackEntry.stack)
    var entries: [LogStackEntry]? = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
