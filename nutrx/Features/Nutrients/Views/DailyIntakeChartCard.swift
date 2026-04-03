import SwiftUI
import Charts

struct DailyIntakeChartCard: View {
    let dailyTotals: [(date: Date, total: Double)]
    let dailyTarget: Double
    let unit: String
    var goalType: GoalType = .minimum
    var upperBound: Double? = nil
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
                // Range zone background
                if goalType == .range, let upper = upperBound {
                    RectangleMark(
                        yStart: .value("Min", dailyTarget),
                        yEnd: .value("Max", upper)
                    )
                    .foregroundStyle(.green.opacity(0.08))
                }

                ForEach(dailyTotals, id: \.date) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Intake", entry.total)
                    )
                    .foregroundStyle(barColor(for: entry.total))
                    .cornerRadius(2)
                }

                // Rule marks based on goal type
                switch goalType {
                case .minimum:
                    RuleMark(y: .value("Target", dailyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(dailyTarget.displayString) \(unit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                case .maximum:
                    RuleMark(y: .value("Max", dailyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.orange)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Max \(dailyTarget.displayString)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                case .range:
                    if let upper = upperBound {
                        RuleMark(y: .value("Min", dailyTarget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.green)
                            .annotation(position: .bottom, alignment: .trailing) {
                                Text("Min")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }

                        RuleMark(y: .value("Max", upper))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.orange)
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Max")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
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
        switch goalType {
        case .minimum:
            if total <= 0 {
                return .blue.opacity(0.3)
            }
            guard dailyTarget > 0 else { return .blue }
            if total > dailyTarget {
                let overFraction = min((total - dailyTarget) / dailyTarget, 1.0)
                return blendColor(from: .systemYellow, to: .systemRed, fraction: overFraction)
            } else if total == dailyTarget {
                return .green
            }
            let fraction = total / dailyTarget
            return blendColor(from: .systemBlue, to: .systemGreen, fraction: fraction)

        case .maximum:
            if total <= 0 {
                return .orange.opacity(0.3)
            } else if total > dailyTarget {
                return Color(.systemRed)
            }
            guard dailyTarget > 0 else { return .orange }
            let fraction = total / dailyTarget
            return blendColor(from: .systemOrange, to: .systemRed, fraction: fraction)

        case .range:
            guard let upper = upperBound else { return .blue }
            if total <= 0 {
                return .blue.opacity(0.3)
            } else if total > upper {
                let overFraction = min((total - upper) / upper, 1.0)
                return blendColor(from: .systemYellow, to: .systemRed, fraction: overFraction)
            } else if total >= dailyTarget {
                return .green
            } else {
                guard dailyTarget > 0 else { return .blue }
                let fraction = min(total / dailyTarget, 1.0)
                return blendColor(from: .systemBlue, to: .systemGreen, fraction: fraction)
            }
        }
    }

    private func blendColor(from: UIColor, to: UIColor, fraction: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(min(max(fraction, 0), 1))
        return Color(
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f)
        )
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
