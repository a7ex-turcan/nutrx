import SwiftUI

struct NutrientRowView: View {
    let nutrient: Nutrient
    let currentIntake: Double
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?

    private var showButtons: Bool {
        onIncrement != nil || onDecrement != nil
    }

    private var isComplete: Bool {
        switch nutrient.goalType {
        case .minimum:
            return nutrient.dailyTarget > 0 && currentIntake >= nutrient.dailyTarget
        case .maximum:
            return currentIntake <= nutrient.dailyTarget
        case .range:
            guard let upper = nutrient.upperBound else { return false }
            return currentIntake >= nutrient.dailyTarget && currentIntake <= upper
        }
    }

    private var valueLabel: String {
        switch nutrient.goalType {
        case .minimum, .maximum:
            return "\(currentIntake.displayString) / \(nutrient.dailyTarget.displayString) \(nutrient.unit)"
        case .range:
            let upper = nutrient.upperBound ?? nutrient.dailyTarget
            return "\(currentIntake.displayString) / \(nutrient.dailyTarget.displayString)–\(upper.displayString) \(nutrient.unit)"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Name + intake label
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrient.name)
                        .font(.subheadline.weight(.semibold))

                    if let notes = nutrient.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(isComplete ? .green : .secondary)
            }

            // Progress bar with optional +/- buttons
            HStack(spacing: 14) {
                if showButtons {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDecrement?()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentIntake > 0 ? .red : Color(.systemGray4))
                    }
                    .disabled(currentIntake <= 0)
                    .buttonStyle(.plain)
                }

                NutrientProgressBar(current: currentIntake, target: nutrient.dailyTarget, goalType: nutrient.goalType, upperBound: nutrient.upperBound)

                if showButtons {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onIncrement?()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
    }

}

#Preview {
    VStack(spacing: 12) {
        NutrientRowView(
            nutrient: Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0),
            currentIntake: 2000,
            onIncrement: {},
            onDecrement: {}
        )
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))

        NutrientRowView(
            nutrient: Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 2000, sortOrder: 1),
            currentIntake: 2000
        )
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
