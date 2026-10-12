import Foundation

/// A suggested first nutrient in onboarding (DESIGN.md §5.8). Starting points are pre-fills, not a preset list:
/// picking one fills an editable draft, and nothing is created until the user taps Start tracking.
struct StartingPoint: Identifiable, Equatable {
    let name: String
    let unit: String
    let goalType: GoalType
    let target: Double
    /// Only for `.range`.
    var upperBound: Double? = nil
    let step: Double
    let symbolName: String
    let tint: NutrientTint

    var id: String { name }

    /// The DESIGN.md §5.8 table. The amounts are product defaults to confirm before release — they are
    /// suggestions the user edits, not advice.
    static let all: [StartingPoint] = [
        StartingPoint(name: "Vitamin D", unit: "IU", goalType: .minimum, target: 4000, step: 1000,
                      symbolName: "sun.max", tint: .amber),
        StartingPoint(name: "Magnesium", unit: "mg", goalType: .minimum, target: 400, step: 200,
                      symbolName: "pills", tint: .indigo),
        StartingPoint(name: "Omega-3", unit: "mg", goalType: .minimum, target: 2000, step: 1000,
                      symbolName: "fish", tint: .teal),
        StartingPoint(name: "Water", unit: "L", goalType: .minimum, target: 2.5, step: 0.25,
                      symbolName: "drop", tint: .blue),
        StartingPoint(name: "Protein", unit: "g", goalType: .range, target: 120, upperBound: 160, step: 20,
                      symbolName: "dumbbell", tint: .coral),
        StartingPoint(name: "Creatine", unit: "g", goalType: .minimum, target: 5, step: 5,
                      symbolName: "waterbottle", tint: .green),
    ]

    /// "IU · at least", "g · between".
    var subtitle: String {
        "\(unit) · \(GoalTypePicker.label(for: goalType).lowercased())"
    }

    /// Fills `draft` with this starting point, replacing whatever was there.
    func fill(_ draft: NutrientDraft) {
        draft.reset()
        draft.name = name
        draft.unit = unit
        draft.goalType = goalType
        draft.dailyTarget = NutrientDraft.editableText(target)
        draft.upperBound = upperBound.map { NutrientDraft.editableText($0) } ?? ""
        draft.step = NutrientDraft.editableText(step)
        draft.symbolName = symbolName
        draft.tint = tint
    }
}
