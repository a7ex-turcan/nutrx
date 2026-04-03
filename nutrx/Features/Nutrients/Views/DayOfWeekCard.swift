import SwiftUI
import Charts

struct DayOfWeekCard: View {
    let dayOfWeekAverages: [(weekday: Int, label: String, average: Double)]
    let dailyTarget: Double
    let unit: String
    var goalType: GoalType = .minimum
    var upperBound: Double? = nil

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
                // Range zone background
                if goalType == .range, let upper = upperBound {
                    RectangleMark(
                        yStart: .value("Min", dailyTarget),
                        yEnd: .value("Max", upper)
                    )
                    .foregroundStyle(.green.opacity(0.08))
                }

                ForEach(dayOfWeekAverages, id: \.weekday) { entry in
                    BarMark(
                        x: .value("Day", entry.label),
                        y: .value("Average", entry.average)
                    )
                    .foregroundStyle(entry.average == maxAverage && maxAverage > 0 ? Color.blue : Color.gray.opacity(0.5))
                    .cornerRadius(3)
                }

                // Rule marks based on goal type
                switch goalType {
                case .minimum:
                    RuleMark(y: .value("Target", dailyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                case .maximum:
                    RuleMark(y: .value("Max", dailyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.orange)
                case .range:
                    if let upper = upperBound {
                        RuleMark(y: .value("Min", dailyTarget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.green)

                        RuleMark(y: .value("Max", upper))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.orange)
                    }
                }
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
