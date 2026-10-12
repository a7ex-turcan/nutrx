import Charts
import SwiftUI

/// Daily totals as bars in the nutrient's tint (DESIGN.md §4.8): met days full tint, missed days tint @ 35%,
/// today as a dashed outline (it isn't over yet), and the goal as a dashed rule.
struct DailyIntakeChart: View {
    let days: [AnalyticsDay]
    let goal: AnalyticsGoal
    let tint: NutrientTint
    let nutrientName: String
    let unit: String

    private var isWeek: Bool { days.count <= 7 }
    private var barRadius: CGFloat { isWeek ? 10 : (days.count <= 30 ? 4 : 2) }
    private static let barWidth = 0.7

    private var today: AnalyticsDay? { days.last(where: \.isToday) }

    /// Top of the y-axis: the tallest bar or goal line, plus headroom for the goal label.
    private var yMax: Double {
        let goalTop = goal.goalType == .range ? (goal.upperBound ?? goal.target) : goal.target
        return max(days.map(\.total).max() ?? 0, goalTop, 1) * 1.18
    }

    /// Today's bar is at least a sliver tall so its outline is visible before anything is logged.
    private var todayHeight: Double {
        max(today?.total ?? 0, yMax * 0.1)
    }

    var body: some View {
        Chart {
            ForEach(days.filter { !$0.isToday }) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Intake", day.isTracked ? day.total : 0),
                    width: .ratio(Self.barWidth)
                )
                .cornerRadius(barRadius)
                .foregroundStyle(day.countsAsMet ? tint.color : tint.color.opacity(0.35))
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityValue(accessibilityValue(for: day))
            }

            if let today {
                BarMark(
                    x: .value("Day", today.date, unit: .day),
                    y: .value("Intake", todayHeight),
                    width: .ratio(Self.barWidth)
                )
                .cornerRadius(barRadius)
                .foregroundStyle(tint.color.opacity(today.total > 0 ? 0.25 : 0.08))
                // The bar is drawn at least a sliver tall; VoiceOver and Audio Graph get the real total.
                .accessibilityLabel("Today")
                .accessibilityValue("\(today.total.formattedAmount()) \(unit) so far")
            }

            goalRules
        }
        .chartYScale(domain: 0...yMax)
        .chartYAxis(.hidden)
        .chartXAxis { xAxis }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame {
                    let plot = geo[frame]
                    todayOutline(proxy: proxy, plot: plot)
                    // Labels here rather than as mark annotations: Swift Charts draws later bars over annotations.
                    ForEach(goalLabels, id: \.text) { label in
                        if let y = proxy.position(forY: label.value) {
                            Text(label.text)
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 4)
                                .background(Theme.surfaceCard, in: Capsule())
                                .fixedSize()
                                .frame(width: plot.width, alignment: .trailing)
                                .position(x: plot.midX, y: plot.minY + y + (label.isAbove ? -9 : 9))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: 170)
        .accessibilityLabel("Daily \(nutrientName) intake, last \(days.count) days")
    }

    private func accessibilityValue(for day: AnalyticsDay) -> String {
        guard day.isTracked else { return "Not tracked yet" }
        let amount = "\(day.total.formattedAmount()) \(unit)"
        return day.countsAsMet ? "\(amount), on target" : amount
    }

    private struct GoalLabel {
        let value: Double
        let text: String
        /// Above the line, or below it for a range's minimum so the two never collide.
        let isAbove: Bool
    }

    /// "Goal 4,000" for at-least goals, "Limit 400" for at-most, "Min" / "Max" for a range.
    private var goalLabels: [GoalLabel] {
        func label(_ name: String, _ value: Double, above: Bool = true) -> GoalLabel {
            GoalLabel(value: value, text: "\(name) \(value.formattedAmount())", isAbove: above)
        }
        switch goal.goalType {
        case .minimum:
            return [label("Goal", goal.target)]
        case .maximum:
            return [label("Limit", goal.target)]
        case .range:
            guard let upper = goal.upperBound else { return [label("Goal", goal.target)] }
            return [label("Min", goal.target, above: false), label("Max", upper)]
        }
    }

    @ChartContentBuilder
    private var goalRules: some ChartContent {
        ForEach(goalLabels, id: \.text) { label in
            RuleMark(y: .value("Goal", label.value))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
        }
    }

    /// Today isn't over, so its bar is a dashed outline drawn over the faint placeholder bar.
    @ViewBuilder
    private func todayOutline(proxy: ChartProxy, plot: CGRect) -> some View {
        if let today,
           let end = Calendar.current.date(byAdding: .day, value: 1, to: today.date),
           let start = proxy.position(forX: today.date),
           let finish = proxy.position(forX: end),
           let top = proxy.position(forY: todayHeight),
           let bottom = proxy.position(forY: 0.0) {
            RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                .strokeBorder(tint.color, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .frame(width: (finish - start) * Self.barWidth, height: max(bottom - top, 4))
                .position(x: plot.minX + (start + finish) / 2, y: plot.minY + (top + bottom) / 2)
        }
    }

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        if isWeek {
            AxisMarks(values: days.map(\.date)) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        let isToday = Calendar.current.isDateInToday(date)
                        Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(isToday ? .bold : .semibold))
                            .foregroundStyle(isToday ? Theme.textPrimary : Theme.textSecondary)
                    }
                }
            }
        } else {
            AxisMarks(values: .stride(by: .day, count: days.count <= 30 ? 7 : 30)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct DailyIntakeChartPreview: View {
    let days: Int
    var goal = AnalyticsGoal(goalType: .minimum, target: 4000, upperBound: nil)

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let sample = [4000, 4000, 1500, 5000, 4000, 4000, 2000.0]
        let totals = Dictionary(uniqueKeysWithValues: (0..<days).map { offset in
            (calendar.date(byAdding: .day, value: -offset, to: today)!, sample[offset % sample.count])
        })
        let summary = AnalyticsSummary(dayCount: days, totals: totals, goal: goal,
                                       createdAt: calendar.date(byAdding: .day, value: -120, to: today)!, today: .now)
        return DailyIntakeChart(days: summary.days, goal: goal, tint: .amber, nutrientName: "Vitamin D", unit: "IU")
            .padding(18)
            .cardStyle()
            .padding()
            .frame(maxHeight: .infinity)
            .background(Theme.surfaceGround)
    }
}

#Preview("7 days") { DailyIntakeChartPreview(days: 7) }
#Preview("30 days, dark") { DailyIntakeChartPreview(days: 30).preferredColorScheme(.dark) }
#Preview("Range, 7 days") {
    DailyIntakeChartPreview(days: 7, goal: AnalyticsGoal(goalType: .range, target: 3000, upperBound: 4500))
}
