import WidgetKit

/// One nutrient as the widgets see it: today's total plus what's needed to draw its ring.
struct NutrientSnapshot: Identifiable {
    let id: String
    let name: String
    let unit: String
    let current: Double
    let target: Double
    let step: Double
    let goalType: GoalType
    let upperBound: Double?
    let tint: NutrientTint
    let symbolName: String

    /// Status, ring fraction and text — the same rules as Today (`GoalProgress`).
    var progress: GoalProgress {
        GoalProgress(current: current, goalType: goalType, target: target, upperBound: upperBound, unit: unit)
    }

    var isMet: Bool { progress.countsAsMet }
}

struct NutrxWidgetEntry: TimelineEntry {
    let date: Date
    /// Today's nutrients in Today's order.
    let nutrients: [NutrientSnapshot]
    let isPlaceholder: Bool
    let currentStreak: Int
    let streaksEnabled: Bool
    /// The medium widget's "Running low: Vitamin D · 6 days" (nutrx Pro): the supply that runs out soonest.
    var runningLow: RunningLow? = nil

    struct RunningLow: Equatable {
        let name: String
        /// Whole days left; 0 when out.
        let daysLeft: Int
        let isOut: Bool

        /// "Vitamin D · 6 days", "Vitamin D · 1 day", "Vitamin D · today", "Vitamin D · out".
        var text: String {
            if isOut { return "\(name) · out" }
            switch daysLeft {
            case ...0: return "\(name) · today"
            case 1: return "\(name) · 1 day"
            default: return "\(name) · \(daysLeft) days"
            }
        }
    }

    var metCount: Int { nutrients.filter(\.isMet).count }
    var totalCount: Int { nutrients.count }

    /// The first goal that still needs more, in Today's order: the small widget's "Next" and the rectangular
    /// widget's nutrient. Never an "at most" goal or anything over its limit; logging more wouldn't help.
    var nextUp: NutrientSnapshot? { nutrients.first { $0.progress.needsMore } }

    /// Goals past an "at most" limit or a range's upper bound. With no `nextUp`, these are the unmet ones.
    var overLimitCount: Int { nutrients.filter { $0.progress.status == .overLimit }.count }

    static var placeholder: NutrxWidgetEntry {
        func sample(_ name: String, _ unit: String, _ current: Double, _ target: Double, _ step: Double,
                    _ tint: NutrientTint, _ symbol: String, goalType: GoalType = .minimum,
                    upper: Double? = nil) -> NutrientSnapshot {
            NutrientSnapshot(id: name, name: name, unit: unit, current: current, target: target, step: step,
                             goalType: goalType, upperBound: upper, tint: tint, symbolName: symbol)
        }
        return NutrxWidgetEntry(
            date: .now,
            nutrients: [
                sample("Vitamin D", "IU", 2000, 4000, 1000, .amber, "sun.max"),
                sample("Water", "L", 1.5, 2.5, 0.25, .blue, "drop"),
                sample("Protein", "g", 92, 120, 20, .coral, "dumbbell", goalType: .range, upper: 160),
                sample("Omega-3", "mg", 2000, 2000, 1000, .teal, "fish"),
                sample("Magnesium", "mg", 400, 400, 200, .indigo, "pills"),
                sample("Caffeine", "mg", 240, 400, 80, .brown, "cup.and.saucer", goalType: .maximum),
            ],
            isPlaceholder: true,
            currentStreak: 10,
            streaksEnabled: true
        )
    }

    /// Previews: every goal met except Caffeine, which is over its limit ("1 over limit").
    static var overLimitSample: NutrxWidgetEntry {
        let nutrients = placeholder.nutrients.map { n in
            NutrientSnapshot(id: n.id, name: n.name, unit: n.unit,
                             current: n.goalType == .maximum ? 450 : n.upperBound ?? n.target,
                             target: n.target, step: n.step, goalType: n.goalType, upperBound: n.upperBound,
                             tint: n.tint, symbolName: n.symbolName)
        }
        return NutrxWidgetEntry(date: .now, nutrients: nutrients, isPlaceholder: false, currentStreak: 0,
                                streaksEnabled: true)
    }

    /// The placeholder with Vitamin D running low (nutrx Pro), for previews.
    static var runningLowSample: NutrxWidgetEntry {
        let base = placeholder
        return NutrxWidgetEntry(date: base.date, nutrients: base.nutrients, isPlaceholder: false,
                                currentStreak: base.currentStreak, streaksEnabled: base.streaksEnabled,
                                runningLow: .init(name: "Vitamin D", daysLeft: 6, isOut: false))
    }

    static var empty: NutrxWidgetEntry {
        NutrxWidgetEntry(date: .now, nutrients: [], isPlaceholder: false, currentStreak: 0, streaksEnabled: true)
    }
}
