import SwiftUI
import Charts

struct DayOfWeekCard: View {
    let dayOfWeekAverages: [(weekday: Int, label: String, average: Double)]
    let dailyTarget: Double
    let unit: String

    private var maxAverage: Double {
        dayOfWeekAverages.map(\.average).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Patterns")
                    .font(.headline)
                Text("Last 4 weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(dayOfWeekAverages, id: \.weekday) { entry in
                    BarMark(
                        x: .value("Day", entry.label),
                        y: .value("Average", entry.average)
                    )
                    .foregroundStyle(entry.average == maxAverage && maxAverage > 0 ? Color.blue : Color.gray.opacity(0.5))
                    .cornerRadius(3)
                }

                RuleMark(y: .value("Target", dailyTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
