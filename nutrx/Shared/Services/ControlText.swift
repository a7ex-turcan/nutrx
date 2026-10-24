import Foundation

/// What the Log stack and Log nutrient controls show under their name (nutrx Pro, #138, docs/pro/WIDGETS.md §2).
/// The controls live in the widget extension, which tests can't reach, so the choice is made here
/// (`ControlTextTests`); also compiled into the extension.
enum ControlText {
    enum StackState: Equatable {
        case free
        /// Deleted since the control was set up.
        case removed
        case loggedToday
        /// Nothing in it is due today (deleted nutrients, ended courses, a schedule's off day), so a tap logs nothing.
        case nothingDue
        case ready
    }

    enum NutrientState: Equatable {
        case free
        case removed
        case courseEnded
        /// What one tap logs.
        case ready(step: Double, unit: String)
    }

    /// `stack` is nil when it's gone from the store.
    static func state(of stack: LogStack?, isPro: Bool, now: Date = .now) -> StackState {
        guard isPro else { return .free }
        guard let stack else { return .removed }
        if StackLogging.isLoggedToday(stack, now: now) { return .loggedToday }
        return StackLogging.dueEntries(of: stack, now: now).isEmpty ? .nothingDue : .ready
    }

    /// `nutrient` is nil when it's gone from the store.
    static func state(of nutrient: Nutrient?, isPro: Bool, now: Date = .now) -> NutrientState {
        guard isPro else { return .free }
        guard let nutrient, !nutrient.isRemoved else { return .removed }
        guard nutrient.isRunning(on: now) else { return .courseEnded }
        return .ready(step: nutrient.step, unit: nutrient.unit)
    }

    static func text(_ state: StackState) -> String {
        switch state {
        case .free: "nutrx Pro"
        case .removed: "Removed in nutrx"
        case .loggedToday: "Logged today"
        case .nothingDue: "Nothing due today"
        case .ready: "Log"
        }
    }

    /// A tick once logged today: the small control shows only its symbol, and the text alone left it looking the same.
    static func symbol(_ state: StackState) -> String {
        state == .loggedToday ? "checkmark.circle.fill" : "square.stack.3d.up"
    }

    /// "+1,000 IU" for what a tap logs.
    static func text(_ state: NutrientState, locale: Locale = .current) -> String {
        switch state {
        case .free: "nutrx Pro"
        case .removed: "Removed in nutrx"
        case .courseEnded: "Course ended"
        case .ready(let step, let unit): "+\(step.formattedAmount(locale: locale))\(unit.isEmpty ? "" : " \(unit)")"
        }
    }
}
