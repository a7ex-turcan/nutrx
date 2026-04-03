import SwiftUI

struct PeriodStatsCard: View {
    let hitRate: (onTarget: Int, total: Int)
    let average: Double
    let dailyTarget: Double
    let unit: String
    let period: AnalyticsPeriod
    var goalType: GoalType = .minimum
    var upperBound: Double? = nil

    private var periodLabel: String {
        switch period {
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .quarter: "Last 90 days"
        }
    }

    private var targetDisplay: String {
        switch goalType {
        case .minimum, .maximum:
            return "\(dailyTarget.displayString) \(unit)"
        case .range:
            let upper = upperBound ?? dailyTarget
            return "\(dailyTarget.displayString)–\(upper.displayString) \(unit)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This period")
                    .font(.headline)
                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                statItem(
                    label: "On target",
                    value: "\(hitRate.onTarget) / \(hitRate.total) days"
                )

                Spacer()

                statItem(
                    label: "Daily avg",
                    value: "\(average.displayString) \(unit)"
                )

                Spacer()

                statItem(
                    label: "Target",
                    value: targetDisplay
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
