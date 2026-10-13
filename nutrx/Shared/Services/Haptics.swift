import UIKit

/// The app's haptics, so every logging surface feels the same.
enum Haptics {
    /// After logging an amount: a light tap, or the success pattern when that log reached the goal.
    static func logged(reachingGoal: Bool) {
        if reachingGoal {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// A light tap for small adjustments (removing a step, changing an amount before logging it).
    static func adjusted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A firmer tap when an entry is deleted.
    static func deleted() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
