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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The widest goal label, measured, so the plot leaves exactly that much room on its right for the labels.
    @State private var labelWidth: CGFloat = 0

    /// Goal labels sit in a gutter right of the plot, where no bar reaches (#47). At accessibility sizes even that
    /// gutter would squeeze the bars, so they become a legend line above the chart instead (#66).
    private var labelsInGutter: Bool { !dynamicTypeSize.isAccessibilitySize }
    private static let gutterGap: CGFloat = 6

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
        VStack(alignment: .leading, spacing: 8) {
            if !labelsInGutter {
                legend
            }
            chart
        }
    }

    /// The goal labels as a line above the chart, at accessibility sizes: a dashed swatch and "Goal 4,000".
    /// Side by side when they fit; a range's "Min" and "Max" stack when they don't.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 4) { legendItems }
        }
        .accessibilityHidden(true)
    }

    private var legendItems: some View {
        ForEach(goalLabels, id: \.text) { label in
            HStack(spacing: 6) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 1))
                    path.addLine(to: CGPoint(x: 18, y: 1))
                }
                .stroke(Theme.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: 18, height: 2)
                goalLabelText(label)
            }
        }
    }

    private var chart: some View {
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
        .chartPlotStyle { plot in
            plot.padding(.trailing, labelsInGutter ? labelWidth + Self.gutterGap : 0)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame {
                    let plot = geo[frame]
                    todayOutline(proxy: proxy, plot: plot)
                    // In the gutter right of the plot, where no bar reaches (#47); drawn here rather than as mark
                    // annotations, which Swift Charts draws later bars over.
                    if labelsInGutter {
                        ForEach(goalLabels, id: \.text) { label in
                            if let y = proxy.position(forY: label.value) {
                                goalLabelText(label)
                                    .fixedSize()
                                    .frame(width: labelWidth, alignment: .leading)
                                    .position(x: plot.maxX + Self.gutterGap + labelWidth / 2,
                                              y: plot.minY + y + labelOffset(label))
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: 170)
        .background(alignment: .topLeading) {
            // Measures the widest label for the gutter; never shown.
            VStack(alignment: .leading) {
                ForEach(goalLabels, id: \.text) { goalLabelText($0) }
            }
            .fixedSize()
            .hidden()
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { labelWidth = $0 }
            .accessibilityHidden(true)
        }
        .accessibilityLabel("Daily \(nutrientName) intake, last \(days.count) days")
    }

    private func goalLabelText(_ label: GoalLabel) -> some View {
        Text(label.text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
    }

    /// Centred on its line, except a range's two labels, which move apart (Max up, Min down) so close bounds don't
    /// overlap.
    private func labelOffset(_ label: GoalLabel) -> CGFloat {
        guard goal.goalType == .range else { return 0 }
        return label.isAbove ? -7 : 7
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
            // Half as many dates at accessibility sizes, where weekly ones ran into each other.
            let large = dynamicTypeSize.isAccessibilitySize
            AxisMarks(values: .stride(by: .day, count: days.count <= 30 ? (large ? 14 : 7) : (large ? 45 : 30))) { _ in
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
#Preview("30 days, largest text") { DailyIntakeChartPreview(days: 30).dynamicTypeSize(.accessibility5) }
#Preview("Range, largest text") {
    DailyIntakeChartPreview(days: 30, goal: AnalyticsGoal(goalType: .range, target: 3000, upperBound: 10000))
        .dynamicTypeSize(.accessibility5)
}
