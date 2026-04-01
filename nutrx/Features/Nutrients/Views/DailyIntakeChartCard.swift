import SwiftUI
import Charts

struct DailyIntakeChartCard: View {
    let dailyTotals: [(date: Date, total: Double)]
    let dailyTarget: Double
    let unit: String
    @Binding var selectedPeriod: AnalyticsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily intake")
                    .font(.headline)

                Spacer()

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(AnalyticsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Chart {
                ForEach(dailyTotals, id: \.date) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Intake", entry.total)
                    )
                    .foregroundStyle(barColor(for: entry.total))
                    .cornerRadius(2)
                }

                RuleMark(y: .value("Target", dailyTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(dailyTarget.displayString) \(unit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func barColor(for total: Double) -> Color {
        if total <= 0 {
            return .blue.opacity(0.3)
        } else if total >= dailyTarget {
            return .green
        } else {
            return .blue
        }
    }

    private var xAxisValues: AxisMarkValues {
        switch selectedPeriod {
        case .week:
            return .automatic(desiredCount: 7)
        case .month:
            return .automatic(desiredCount: 6)
        case .quarter:
            return .automatic(desiredCount: 5)
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month, .quarter:
            return .dateTime.day().month(.abbreviated)
        }
    }
}
