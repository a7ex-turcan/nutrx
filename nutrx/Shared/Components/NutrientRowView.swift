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
        nutrient.dailyTarget > 0 && currentIntake >= nutrient.dailyTarget
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

                Text("\(currentIntake.displayString) / \(nutrient.dailyTarget.displayString) \(nutrient.unit)")
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

                NutrientProgressBar(current: currentIntake, target: nutrient.dailyTarget)

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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        NutrientRowView(
            nutrient: Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 2000, sortOrder: 1),
            currentIntake: 2000
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
