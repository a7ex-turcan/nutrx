import SwiftUI

/// Live preview at the top of the nutrient form: ring in the chosen tint and symbol, the name, and
/// "0 / 5 g · +5 g per tap". Updates as the user types (DESIGN.md §4.10).
struct NutrientPreviewRow: View {
    let name: String
    let unit: String
    let tint: NutrientTint
    let symbolName: String
    let goalType: GoalType
    let target: Double?
    let upperBound: Double?
    let step: Double?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How far the preview ring is drawn, just to show the colour.
    private static let sampleFraction = 0.35

    /// The goal after the "0" ("/ 5 g", "max 400 mg"), or nil until there's a target.
    private var goalText: String? {
        target.map { target in
            GoalProgress(current: 0, goalType: goalType, target: target, upperBound: upperBound,
                         unit: unit.trimmingCharacters(in: .whitespaces)).goalText
        }
    }

    /// "+5 g per tap", or nil until there's a step.
    private var stepText: String? {
        guard let step, step > 0 else { return nil }
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let amount = trimmedUnit.isEmpty ? step.formattedAmount() : "\(step.formattedAmount()) \(trimmedUnit)"
        return "+\(amount) per tap"
    }

    /// "0 / 5 g · +5 g per tap", or a prompt before anything is entered.
    private var goalLine: String {
        let parts = [goalText.map { "0 \($0)" }, stepText].compactMap { $0 }
        return parts.isEmpty ? "Set a goal below" : parts.joined(separator: " · ")
    }

    /// `goalLine` with the 0 bold, rounded and primary, like the value on a Today card (DESIGN.md §0.5, §4.4).
    private var goalLineText: Text {
        guard let goalText else { return Text(goalLine) }
        let rest = [goalText, stepText].compactMap { $0 }.joined(separator: " · ")
        return Text("0").font(.subheadline.weight(.bold)).fontDesign(.rounded).foregroundStyle(Theme.textPrimary)
            + Text(" \(rest)")
    }

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(fraction: Self.sampleFraction, color: tint.color, trackColor: tint.trackColor,
                         symbolName: symbolName)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "New nutrient" : name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                goalLineText
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            // At accessibility sizes the tag would take a quarter of the row and break the name.
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Preview")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 12)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

extension NutrientPreviewRow {
    init(draft: NutrientDraft) {
        self.init(
            name: draft.name,
            unit: draft.unit,
            tint: draft.tint,
            symbolName: draft.symbolName,
            goalType: draft.goalType,
            target: draft.dailyTarget.parsedDouble,
            upperBound: draft.upperBound.parsedDouble,
            step: draft.step.parsedDouble
        )
    }
}

private struct NutrientPreviewRowGallery: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.cardGap) {
            NutrientPreviewRow(name: "Creatine", unit: "g", tint: .teal, symbolName: "waterbottle",
                               goalType: .minimum, target: 5, upperBound: nil, step: 5)
            NutrientPreviewRow(name: "Caffeine", unit: "mg", tint: .brown, symbolName: "cup.and.saucer",
                               goalType: .maximum, target: 400, upperBound: nil, step: 100)
            NutrientPreviewRow(name: "", unit: "", tint: .green, symbolName: "pills",
                               goalType: .minimum, target: nil, upperBound: nil, step: nil)
        }
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    NutrientPreviewRowGallery()
}

#Preview("Dark") {
    NutrientPreviewRowGallery()
        .preferredColorScheme(.dark)
}
