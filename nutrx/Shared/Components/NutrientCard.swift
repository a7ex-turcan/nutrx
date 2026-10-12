import SwiftData
import SwiftUI

/// Today's nutrient row (DESIGN.md §4.4): progress ring with the nutrient's symbol, name, value and
/// status line, then − / + step buttons. Tapping the card body calls `onOpen`.
struct NutrientCard: View {
    let nutrient: Nutrient
    let currentIntake: Double
    var onOpen: () -> Void = {}
    var onIncrement: () -> Void = {}
    var onDecrement: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: GoalProgress {
        GoalProgress(nutrient: nutrient, current: currentIntake)
    }

    var body: some View {
        let progress = progress

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Large text: details get the full width, buttons move to their own row.
                VStack(alignment: .trailing, spacing: Theme.Spacing.cardPadding) {
                    details(progress)
                    stepButtons
                }
            } else {
                HStack(spacing: 14) {
                    details(progress)
                    stepButtons
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
    }

    private func details(_ progress: GoalProgress) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ProgressRing(nutrient: nutrient, progress: progress)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrient.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("\(Text(progress.currentText).font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(Theme.textPrimary)) \(Text(progress.goalText).font(.subheadline).foregroundStyle(Theme.textSecondary))")
                        .monospacedDigit()

                    Text(progress.remainingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(progress.status.textColor)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrient.name)
        .accessibilityValue("\(progress.progressText), \(progress.remainingText)")
        .accessibilityHint("Opens logging options")
    }

    /// Same rule as `TodayViewModel.decrement`, which ignores a step that would take the total below zero.
    private var canDecrement: Bool {
        currentIntake - nutrient.step >= 0
    }

    private var stepButtons: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .overlay(Circle().strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5))
                    .contentShape(Circle())
            }
            .disabled(!canDecrement)
            .opacity(canDecrement ? 1 : 0.4)
            .accessibilityLabel("Remove one step of \(nutrient.name)")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .background(Theme.controlPrimary, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Add one step of \(nutrient.name)")
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - Previews

private struct NutrientCardPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.cardGap) {
                card("Vitamin D", unit: "IU", target: 4000, current: 2000, tint: .amber, symbol: "sun.max")
                card("Omega-3", unit: "mg", target: 2000, current: 2000, tint: .teal, symbol: "fish")
                card("Water", unit: "L", target: 2.5, current: 0, tint: .blue, symbol: "drop")
                card("Caffeine", unit: "mg", target: 400, current: 320, tint: .brown, symbol: "cup.and.saucer", goal: .maximum)
                card("Protein", unit: "g", target: 120, upper: 160, current: 92, tint: .coral, symbol: "dumbbell", goal: .range)
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
    }

    private func card(_ name: String, unit: String, target: Double, upper: Double? = nil, current: Double,
                      tint: NutrientTint, symbol: String, goal: GoalType = .minimum) -> some View {
        let nutrient = Nutrient(name: name, unit: unit, step: 1, dailyTarget: target, sortOrder: 0,
                                goalType: goal, upperBound: upper)
        nutrient.tint = tint
        nutrient.symbolName = symbol
        return NutrientCard(nutrient: nutrient, currentIntake: current)
    }
}

#Preview("Light") {
    NutrientCardPreviewGallery()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    NutrientCardPreviewGallery()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    NutrientCardPreviewGallery()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
