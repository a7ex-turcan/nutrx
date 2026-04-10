import SwiftUI
import WatchKit

struct WatchNutrientRowView: View {
    let nutrient: Nutrient
    let total: Double
    let onIncrement: () -> Void

    private var progressColor: Color {
        switch nutrient.goalType {
        case .minimum:
            guard nutrient.dailyTarget > 0 else { return .blue }
            if total > nutrient.dailyTarget { return .yellow }
            if total >= nutrient.dailyTarget { return .green }
            let fraction = total / nutrient.dailyTarget
            return fraction > 0.7 ? .green.opacity(0.7) : .blue

        case .maximum:
            guard nutrient.dailyTarget > 0 else { return .orange }
            if total > nutrient.dailyTarget { return .red }
            let fraction = total / nutrient.dailyTarget
            return fraction > 0.7 ? .red.opacity(0.7) : .orange

        case .range:
            guard let upper = nutrient.upperBound, upper > 0 else { return .blue }
            if total > upper { return .red }
            if total >= nutrient.dailyTarget { return .green }
            let fraction = nutrient.dailyTarget > 0 ? total / nutrient.dailyTarget : 0
            return fraction > 0.7 ? .green.opacity(0.7) : .blue
        }
    }

    private var progress: Double {
        switch nutrient.goalType {
        case .minimum:
            guard nutrient.dailyTarget > 0 else { return 0 }
            return min(total / nutrient.dailyTarget, 1.0)
        case .maximum:
            guard nutrient.dailyTarget > 0 else { return 0 }
            return min(total / nutrient.dailyTarget, 1.0)
        case .range:
            guard let upper = nutrient.upperBound, upper > 0 else { return 0 }
            return min(total / upper, 1.0)
        }
    }

    private var valueLabel: String {
        let currentStr = total.displayString
        switch nutrient.goalType {
        case .minimum, .maximum:
            return "\(currentStr) / \(nutrient.dailyTarget.displayString) \(nutrient.unit)"
        case .range:
            let lower = nutrient.dailyTarget.displayString
            let upper = (nutrient.upperBound ?? nutrient.dailyTarget).displayString
            return "\(currentStr) / \(lower)\u{2013}\(upper) \(nutrient.unit)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(nutrient.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    WKInterfaceDevice.current().play(.click)
                    onIncrement()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.darkGray))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 6)

            Text(valueLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
