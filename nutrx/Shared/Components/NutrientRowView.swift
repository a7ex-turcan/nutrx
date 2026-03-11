import SwiftUI

struct NutrientRowView: View {
    let nutrient: Nutrient
    let currentIntake: Double
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    private var isComplete: Bool {
        nutrient.dailyTarget > 0 && currentIntake >= nutrient.dailyTarget
    }

    var body: some View {
        VStack(spacing: 10) {
            // Name + intake label
            HStack {
                Text(nutrient.name)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(formatted(currentIntake)) / \(formatted(nutrient.dailyTarget)) \(nutrient.unit)")
                    .font(.caption)
                    .foregroundStyle(isComplete ? .green : .secondary)
            }

            // Progress bar with +/- buttons
            HStack(spacing: 14) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentIntake > 0 ? .red : Color(.systemGray4))
                }
                .disabled(currentIntake <= 0)
                .buttonStyle(.plain)

                NutrientProgressBar(current: currentIntake, target: nutrient.dailyTarget)

                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    VStack(spacing: 12) {
        NutrientRowView(
            nutrient: {
                let n = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
                return n
            }(),
            currentIntake: 2000,
            onIncrement: {},
            onDecrement: {}
        )
        NutrientRowView(
            nutrient: {
                let n = Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 2000, sortOrder: 1)
                return n
            }(),
            currentIntake: 2000,
            onIncrement: {},
            onDecrement: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
