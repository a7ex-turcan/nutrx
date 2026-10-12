import Foundation

/// Where a nutrient stands against its daily goal (DESIGN.md §2).
enum GoalStatus: Equatable {
    /// Working toward the goal — includes being below a range's lower bound.
    case inProgress
    /// At least: target reached. Between: inside the range.
    case met
    /// At most: 75–100% of the limit used. Still counts as met.
    case nearingLimit
    /// At most: past the limit. Between: past the upper bound.
    case overLimit
}

/// One nutrient's progress for one day. The single source of truth for ring fill, status colour,
/// status line and whether the goal counts as met — shared by Today, History, streaks, widgets and Watch.
struct GoalProgress: Equatable {
    let status: GoalStatus
    /// 0…1, for drawing the ring.
    let ringFraction: Double
    /// Whether this goal counts toward the day score and streaks.
    let countsAsMet: Bool
    /// The day's total, floored at 0.
    let current: Double
    let unit: String
    private let goal: Goal

    /// Share of an "at most" limit at which the ring turns amber.
    static let nearingLimitThreshold = 0.75

    private enum Goal: Equatable {
        case atLeast(Double)
        case atMost(Double)
        case between(lower: Double, upper: Double)
    }

    init(current: Double, goalType: GoalType, target: Double, upperBound: Double? = nil, unit: String = "") {
        let current = max(0, current)
        self.current = current
        self.unit = unit

        switch goalType {
        case .minimum:
            goal = .atLeast(target)
        case .maximum:
            goal = .atMost(target)
        case .range:
            // A range without an upper bound only exists in legacy data — treat it as "at least".
            if let upperBound {
                goal = .between(lower: target, upper: upperBound)
            } else {
                goal = .atLeast(target)
            }
        }

        switch goal {
        case .atLeast(let target):
            let met = Self.reached(current, target)
            status = met ? .met : .inProgress
            ringFraction = Self.fraction(current, of: target)
            countsAsMet = met

        case .atMost(let limit):
            if Self.reached(limit, current) {
                status = Self.reached(current, limit * Self.nearingLimitThreshold) ? .nearingLimit : .inProgress
                countsAsMet = true
            } else {
                status = .overLimit
                countsAsMet = false
            }
            ringFraction = Self.fraction(current, of: limit)

        case .between(let lower, let upper):
            if !Self.reached(upper, current) {
                status = .overLimit
                countsAsMet = false
            } else if Self.reached(current, lower) {
                status = .met
                countsAsMet = true
            } else {
                status = .inProgress
                countsAsMet = false
            }
            ringFraction = Self.fraction(current, of: upper)
        }
    }

    init(nutrient: Nutrient, current: Double) {
        self.init(
            current: current,
            goalType: nutrient.goalType,
            target: nutrient.dailyTarget,
            upperBound: nutrient.upperBound,
            unit: nutrient.unit
        )
    }

    // MARK: - Text

    /// Status line under the value: "2,000 IU to go", "80 mg left today", "28 g to range", "Done".
    var remainingText: String { remainingText(locale: .current) }

    /// Current against the goal: "2,000 of 4,000 IU", "130 of 120–160 g". Used for VoiceOver values.
    var progressText: String { progressText(locale: .current) }

    /// The day's total on its own, for the bold part of a value line: "2,000".
    var currentText: String { currentText(locale: .current) }

    /// The goal after the bold total: "/ 4,000 IU", "max 400 mg", "/ 120–160 g".
    var goalText: String { goalText(locale: .current) }

    func remainingText(locale: Locale) -> String {
        switch goal {
        case .atLeast(let target):
            return countsAsMet ? "Done" : "\(amount(target - current, locale)) to go"
        case .atMost(let limit):
            if status == .overLimit { return "\(amount(current - limit, locale)) over limit" }
            return Self.reached(current, limit) ? "Limit reached" : "\(amount(limit - current, locale)) left today"
        case .between(let lower, let upper):
            switch status {
            case .overLimit: return "\(amount(current - upper, locale)) over range"
            case .met: return "In range"
            default: return "\(amount(lower - current, locale)) to range"
            }
        }
    }

    func progressText(locale: Locale) -> String {
        let value = Self.number(current, locale)
        switch goal {
        case .atLeast(let target), .atMost(let target):
            return "\(value) of \(amount(target, locale))"
        case .between(let lower, let upper):
            return "\(value) of \(Self.number(lower, locale))–\(amount(upper, locale))"
        }
    }

    func currentText(locale: Locale) -> String {
        Self.number(current, locale)
    }

    func goalText(locale: Locale) -> String {
        switch goal {
        case .atLeast(let target):
            return "/ \(amount(target, locale))"
        case .atMost(let limit):
            return "max \(amount(limit, locale))"
        case .between(let lower, let upper):
            return "/ \(Self.number(lower, locale))–\(amount(upper, locale))"
        }
    }

    // MARK: - Helpers

    /// `value ≥ threshold`, tolerant of float drift from summing steps (0.1 + 0.7 must reach 0.8).
    private static func reached(_ value: Double, _ threshold: Double) -> Bool {
        value >= threshold - 1e-9 * max(1, abs(threshold))
    }

    private static func fraction(_ value: Double, of whole: Double) -> Double {
        guard whole > 0 else { return 1 }
        return min(max(value / whole, 0), 1)
    }

    private func amount(_ value: Double, _ locale: Locale) -> String {
        let number = Self.number(value, locale)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    private static func number(_ value: Double, _ locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
}
