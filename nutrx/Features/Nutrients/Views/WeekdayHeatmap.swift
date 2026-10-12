import SwiftUI

/// Seven squares, one per weekday, filled by the 4-week hit rate (DESIGN.md §4.8), plus a one-line
/// insight when one weekday clearly lags. No advice beyond that.
struct WeekdayHeatmap: View {
    let pattern: WeekdayPattern
    let tint: NutrientTint

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekday pattern")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Last 4 weeks")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(pattern.entries) { entry in
                    day(entry)
                }
            }

            if let weakest = pattern.weakestWeekday {
                Text("\(calendar.weekdaySymbols[weakest - 1])s are your weakest day.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func day(_ entry: WeekdayPattern.Entry) -> some View {
        let opacity = WeekdayPattern.fillOpacity(for: entry.hitRate)
        let percent = entry.hitRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–"

        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous)
                .fill(tint.color.opacity(opacity))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text(percent)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        // Dark ink on the strong fills; normal text on the faint ones (light in dark mode).
                        .foregroundStyle(opacity >= 0.7 ? Theme.textOnTint : Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(2)
                }
            Text(calendar.veryShortWeekdaySymbols[entry.weekday - 1])
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calendar.weekdaySymbols[entry.weekday - 1])
        .accessibilityValue(entry.hitRate == nil ? "No days yet" : "\(percent) of days on target")
    }
}

private struct WeekdayHeatmapPreview: View {
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let goal = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)
        // Met every day except most Sundays.
        let totals = Dictionary(uniqueKeysWithValues: (1...28).map { offset -> (Date, Double) in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let isSunday = calendar.component(.weekday, from: date) == 1
            return (date, isSunday && offset > 7 ? 0 : 1)
        })
        let pattern = WeekdayPattern(totals: totals, goal: goal,
                                     createdAt: calendar.date(byAdding: .day, value: -60, to: today)!, today: .now)
        return WeekdayHeatmap(pattern: pattern, tint: .amber)
            .padding(18)
            .cardStyle()
            .padding()
            .frame(maxHeight: .infinity)
            .background(Theme.surfaceGround)
    }
}

#Preview("Light") { WeekdayHeatmapPreview() }
#Preview("Dark") { WeekdayHeatmapPreview().preferredColorScheme(.dark) }
