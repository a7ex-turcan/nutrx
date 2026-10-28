import SwiftUI

/// The month's full days on a small calendar (#136, docs/pro/RECAPS.md §5): a full day in green, another day with
/// something due outlined, and a day with nothing due (a rest day, before anything was tracked) or still to come
/// faint. One VoiceOver element: "18 of 30 full days in October".
struct RecapMonthGrid: View {
    let recap: MonthlyRecap

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var grid: MonthGrid { MonthGrid(containing: recap.monthStart) }

    var body: some View {
        let grid = grid
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        VStack(alignment: .leading, spacing: 10) {
            Text("Full days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: columns, spacing: 6) {
                // Ids that don't collide in the one grid: the weekdays' 0…6, "blank-n", the days' dates (days by
                // index hid the 1st to the 7th behind the weekday letters).
                ForEach(Array(grid.narrowWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach((0..<grid.leadingBlanks).map { "blank-\($0)" }, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(Array(grid.days.enumerated()), id: \.element) { index, day in
                    cell(day: index + 1, full: recap.fullDayFlags.indices.contains(index) && recap.fullDayFlags[index],
                         counted: recap.dueDayFlags.indices.contains(index) && recap.dueDayFlags[index])
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // seven columns, as History's calendar
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recap.fullDays) of \(recap.dayCount) full days in \(MonthlyRecapText(recap).monthName)")
    }

    private func cell(day: Int, full: Bool, counted: Bool) -> some View {
        Text("\(day)")
            .font(.caption.weight(full ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(full ? Theme.textOnTint : counted ? Theme.textPrimary : Theme.textSecondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background {
                if full {
                    Circle().fill(Theme.green)
                } else if counted {
                    Circle().stroke(Theme.surfaceChip, lineWidth: 1.5)
                }
            }
    }
}

#if DEBUG
#Preview("Light") {
    RecapMonthGrid(recap: RecapPreviewSample.month)
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    RecapMonthGrid(recap: RecapPreviewSample.month)
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
#endif
