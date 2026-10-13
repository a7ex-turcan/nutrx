#if DEBUG
import Foundation

/// Unsaved sample nutrients for Watch previews, matching the DESIGN.md §5.11 render.
enum WatchPreviewData {
    static let items: [WatchNutrientItem] = [
        item("Vitamin D", "IU", step: 1000, target: 4000, total: 2000, tint: .amber, symbol: "sun.max"),
        item("Water", "L", step: 0.25, target: 2.5, total: 1.5, tint: .blue, symbol: "drop"),
        // A long range, to show its value moving to a second line whole instead of breaking mid-range.
        item("Sodium", "mg", step: 500, target: 2300, upper: 3500, total: 2500, tint: .pink, symbol: "pills"),
        item("Protein", "g", step: 20, target: 120, upper: 160, total: 92, tint: .coral, symbol: "dumbbell"),
        item("Caffeine", "mg", step: 80, target: 400, goalType: .maximum, total: 320, tint: .brown,
             symbol: "cup.and.saucer"),
        item("Omega-3", "mg", step: 1000, target: 2000, total: 2000, tint: .teal, symbol: "fish"),
    ]

    static var confirmation: WatchLogConfirmation {
        let vitaminD = items[0]
        return WatchLogConfirmation(item: WatchNutrientItem(nutrient: vitaminD.nutrient, total: 3000),
                                    amount: 1000, metGoal: false)
    }

    private static func item(_ name: String, _ unit: String, step: Double, target: Double, upper: Double? = nil,
                             goalType: GoalType? = nil, total: Double, tint: NutrientTint,
                             symbol: String) -> WatchNutrientItem {
        let nutrient = Nutrient(name: name, unit: unit, step: step, dailyTarget: target, sortOrder: 0)
        nutrient.goalType = goalType ?? (upper == nil ? .minimum : .range)
        nutrient.upperBound = upper
        nutrient.tint = tint
        nutrient.symbolName = symbol
        return WatchNutrientItem(nutrient: nutrient, total: total)
    }
}
#endif
