import Foundation

/// A suggested first nutrient in onboarding (DESIGN.md §5.8). Starting points are pre-fills, not a preset list:
/// picking one fills an editable draft, and nothing is created until the user taps Start tracking.
///
/// They carry no amounts. nutrx doesn't recommend intakes, so the user types their own goal and step.
struct StartingPoint: Identifiable, Equatable {
    let name: String
    let unit: String
    let goalType: GoalType
    let symbolName: String
    let tint: NutrientTint

    var id: String { name }

    /// The DESIGN.md §5.8 table.
    static let all: [StartingPoint] = [
        StartingPoint(name: "Vitamin D", unit: "IU", goalType: .minimum, symbolName: "sun.max", tint: .amber),
        StartingPoint(name: "Magnesium", unit: "mg", goalType: .minimum, symbolName: "pills", tint: .indigo),
        StartingPoint(name: "Omega-3", unit: "mg", goalType: .minimum, symbolName: "fish", tint: .teal),
        StartingPoint(name: "Water", unit: "L", goalType: .minimum, symbolName: "drop", tint: .blue),
        StartingPoint(name: "Protein", unit: "g", goalType: .range, symbolName: "dumbbell", tint: .coral),
        StartingPoint(name: "Creatine", unit: "g", goalType: .minimum, symbolName: "waterbottle", tint: .green),
    ]

    /// "IU · at least", "g · between".
    var subtitle: String {
        "\(unit) · \(GoalTypePicker.label(for: goalType).lowercased())"
    }

    /// Fills `draft` with this starting point, replacing whatever was there. The goal and step stay empty for the
    /// user to enter.
    func fill(_ draft: NutrientDraft) {
        draft.reset()
        draft.name = name
        draft.unit = unit
        draft.goalType = goalType
        draft.symbolName = symbolName
        draft.tint = tint
    }
}
