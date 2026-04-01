import SwiftUI

struct PeriodStatsCard: View {
    let hitRate: (onTarget: Int, total: Int)
    let average: Double
    let dailyTarget: Double
    let unit: String
    let period: AnalyticsPeriod

    private var periodLabel: String {
        switch period {
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .quarter: "Last 90 days"
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
                    value: "\(dailyTarget.displayString) \(unit)"
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
