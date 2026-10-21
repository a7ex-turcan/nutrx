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
    /// The supply hint for the third line (nutrx Pro): low or out, nil otherwise.
    var supply: SupplyHint? = nil
    var onRefill: () -> Void = {}
    /// A course's last day (nutrx Pro, #128): "Last day" on the third line, in place of a low-supply hint.
    var isLastDay: Bool = false
    /// A VoiceOver "Edit Nutrient" action, for layouts without swipe actions (Today's grid on large screens, #152).
    var onEdit: (() -> Void)? = nil

    /// What Today shows about supply: "About 6 days left", or out with a Refilled? link.
    struct SupplyHint: Equatable {
        let text: String
        /// "6 days left", tried next to the goal status before the hint takes the line alone.
        var shortText: String? = nil
        /// "6 days" with the bottle, the last try before the hint takes the line alone.
        var compactText: String? = nil
        let isOut: Bool
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widthClass) private var widthClass

    private var progress: GoalProgress {
        GoalProgress(nutrient: nutrient, current: currentIntake)
    }

    var body: some View {
        let progress = progress

        Group {
            if largeLayout {
                // Large text on a large screen (LAYOUT.md, #155): a full-width − / + row with 64 pt targets.
                VStack(alignment: .leading, spacing: Theme.Spacing.cardPadding) {
                    details(progress)
                    capsuleStepButtons
                }
            } else if dynamicTypeSize.isAccessibilitySize {
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
        .padding(largeLayout ? 20 : Theme.Spacing.cardPadding)
        .cardStyle()
    }

    /// Largest text sizes on a large screen: a bigger ring, roomier padding and the capsule − / + row (TodayAX).
    private var largeLayout: Bool { dynamicTypeSize.isAccessibilitySize && widthClass != .compact }

    private func details(_ progress: GoalProgress) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ProgressRing(nutrient: nutrient, progress: progress)
                    .frame(width: largeLayout ? 64 : 52, height: largeLayout ? 64 : 52)
                    .accessibilityHidden(true)  // the card's own label and value say it

                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrient.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("\(Text(progress.currentText).font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(Theme.textPrimary)) \(Text(progress.goalText).font(.subheadline).foregroundStyle(Theme.textSecondary))")
                        .monospacedDigit()

                    statusLine(progress)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrient.name)
        .accessibilityValue(accessibilityValue(progress))
        .accessibilityActions {
            if supply?.isOut == true {
                Button("Refilled", action: onRefill)
            }
            if let onEdit {
                Button("Edit Nutrient", action: onEdit)
            }
        }
        .accessibilityHint("Opens logging options")
        .accessibilityAddTraits(.isButton)  // children: .ignore can drop the button's own trait
    }

    /// A short note that shares the third line with the goal status: supply running low, or a course's last day.
    private struct LineHint {
        let symbol: String
        let text: String
        var shortText: String? = nil
        var compactText: String? = nil
        let color: Color
    }

    /// On a course's last day that beats a low-supply hint: the days of supply left past the course don't matter.
    private var lineHint: LineHint? {
        if isLastDay {
            return LineHint(symbol: "hourglass", text: CourseText.lastDay, color: Theme.textSecondary)
        }
        if let supply, !supply.isOut {
            return LineHint(symbol: "waterbottle", text: supply.text, shortText: supply.shortText,
                            compactText: supply.compactText, color: Theme.textAmberInk)
        }
        return nil
    }

    /// The third line. With a hint it's shared, so the card's height never changes: "2,000 IU to go · About 6 days
    /// left" (amber with a bottle), "2,000 IU to go · Last day" (an hourglass), or "Out of supply · Refilled?" in
    /// place of the goal status. If both don't fit on one line, the hint stays.
    @ViewBuilder
    private func statusLine(_ progress: GoalProgress) -> some View {
        let goal = Text(progress.remainingText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(progress.status.textColor)
        if let supply, supply.isOut {
            // Shorter until it fits on the line ("Out of supply · Refilled?" was cut off on an iPhone 17e, #185);
            // at accessibility sizes the card grows, so the two parts wrap instead.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    outText(supply.text)
                    refilledButton
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    outLine { outText("\(supply.text) ·") }
                    if let compact = supply.compactText {
                        outLine { bottle; outText("\(compact) ·") }
                    }
                    outLine(fixed: false) { bottle }  // the last try may truncate rather than push into the buttons
                }
            }
        } else if let hint = lineHint {
            if dynamicTypeSize.isAccessibilitySize {
                // Wrapping is fine here: the card already grows at these sizes.
                VStack(alignment: .leading, spacing: 2) { goal; hintView(hint, hint.text) }
            } else {
                ViewThatFits(in: .horizontal) {
                    sharedLine(goal, hint, hint.text)
                    if let short = hint.shortText { sharedLine(goal, hint, short) }
                    if let compact = hint.compactText { sharedLine(goal, hint, compact) }
                    // Alone, it shortens too: "About 6 day…" was cut off at XXXL on an iPhone 17e (#185).
                    hintView(hint, hint.text).lineLimit(1).fixedSize()
                    if let short = hint.shortText { hintView(hint, short).lineLimit(1).fixedSize() }
                    hintView(hint, hint.compactText ?? hint.shortText ?? hint.text).lineLimit(1)
                }
            }
        } else {
            goal
        }
    }

    private func outText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
    }

    private var bottle: some View {
        Image(systemName: "waterbottle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .accessibilityHidden(true)
    }

    private var refilledButton: some View {
        Button("Refilled?", action: onRefill)
            .font(.caption.weight(.semibold))
            .underline()
            .foregroundStyle(Theme.textGreenInk)
            .buttonStyle(.plain)
            .accessibilityHidden(true)  // the card's "Refilled" action
    }

    private func outLine(fixed: Bool = true, @ViewBuilder _ lead: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            lead()
            refilledButton
        }
        .lineLimit(1)
        .fixedSize(horizontal: fixed, vertical: false)
    }

    private func hintView(_ hint: LineHint, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: hint.symbol)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(hint.color)
    }

    private func sharedLine(_ goal: some View, _ hint: LineHint, _ text: String) -> some View {
        HStack(spacing: 4) {
            goal
            Text("·").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            hintView(hint, text)
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// "2,000 / 4,000 IU, 2,000 IU to go", plus what the third line shows: out of supply (in place of the goal
    /// status), else a course's last day, else a low-supply hint, so VoiceOver says what the screen does.
    private func accessibilityValue(_ progress: GoalProgress) -> String {
        var parts = [progress.progressText]
        if let supply, supply.isOut {
            parts.append(supply.text)
        } else {
            parts.append(progress.remainingText)
            if isLastDay {
                parts.append(CourseText.lastDaySpoken)
            } else if let supply {
                parts.append(supply.text)
            }
        }
        return parts.joined(separator: ", ")
    }

    /// Same rule as `TodayViewModel.decrement`, which ignores a step that would take the total below zero.
    private var canDecrement: Bool {
        currentIntake - nutrient.step >= 0
    }

    private var stepButtons: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.adjusted()
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
                Haptics.logged(reachingGoal: progress.reachesGoal(adding: nutrient.step))
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

extension NutrientCard {
    /// − and + as two equal capsules across the card, 64 pt tall (largest text sizes on large screens).
    private var capsuleStepButtons: some View {
        HStack(spacing: 16) {
            Button {
                Haptics.adjusted()
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay(Capsule().strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5))
                    .contentShape(Capsule())
            }
            .disabled(!canDecrement)
            .opacity(canDecrement ? 1 : 0.4)
            .accessibilityLabel("Remove one step of \(nutrient.name)")

            Button {
                Haptics.logged(reachingGoal: progress.reachesGoal(adding: nutrient.step))
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.controlPrimary, in: Capsule())
                    .contentShape(Capsule())
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
                card("Zinc", unit: "mg", target: 25, current: 10, tint: .green, symbol: "pills", lastDay: true)
                card("Magnesium", unit: "mg", target: 400, current: 400, tint: .indigo, symbol: "pills", lastDay: true)
                card("Omega-3 Fish Oil", unit: "mg", target: 2000, current: 1000, tint: .teal, symbol: "fish",
                     supply: .init(text: "Out of supply", shortText: "Out of supply", compactText: "Out", isOut: true))
                card("Vitamin B12", unit: "mcg", target: 1000, current: 0, tint: .pink, symbol: "pills",
                     supply: .init(text: "About 6 days left", shortText: "6 days left", compactText: "6 days", isOut: false))
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
    }

    private func card(_ name: String, unit: String, target: Double, upper: Double? = nil, current: Double,
                      tint: NutrientTint, symbol: String, goal: GoalType = .minimum, lastDay: Bool = false,
                      supply: NutrientCard.SupplyHint? = nil) -> some View {
        let nutrient = Nutrient(name: name, unit: unit, step: 1, dailyTarget: target, sortOrder: 0,
                                goalType: goal, upperBound: upper)
        nutrient.tint = tint
        nutrient.symbolName = symbol
        return NutrientCard(nutrient: nutrient, currentIntake: current, supply: supply, isLastDay: lastDay)
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
