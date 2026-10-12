import SwiftUI

/// Month grid of day circles coloured by how many goals were met (DESIGN.md §4.9), with a month switcher and a
/// legend. Past days with entries are tappable.
struct MonthCalendar: View {
    let grid: MonthGrid
    /// Start of today.
    let today: Date
    let completion: (Date) -> DayCompletion
    let canShowPrevious: Bool
    let canShowNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelect: (Date) -> Void

    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 38
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            header

            LazyVGrid(columns: columns, spacing: 8) {
                let symbols = dynamicTypeSize.isAccessibilitySize ? grid.narrowWeekdaySymbols : grid.weekdaySymbols
                ForEach(symbols.indices, id: \.self) { index in
                    Text(symbols[index].uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true)
                }
                ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: cellSize)
                        .accessibilityHidden(true)
                }
                ForEach(grid.days, id: \.self) { date in
                    cell(date)
                }
            }

            legend
        }
    }

    private var header: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(chevronColor(enabled: canShowPrevious))
            .disabled(!canShowPrevious)
            .accessibilityLabel("Previous month")

            Spacer()
            Text(grid.month, format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(chevronColor(enabled: canShowNext))
            .disabled(!canShowNext)
            .accessibilityLabel("Next month")
        }
        .font(.body.weight(.semibold))
    }

    /// Set explicitly — a custom foreground style would otherwise hide the disabled state.
    private func chevronColor(enabled: Bool) -> Color {
        enabled ? Theme.controlPrimary : Theme.textSecondary.opacity(0.4)
    }

    @ViewBuilder
    private func cell(_ date: Date) -> some View {
        let isToday = date == today
        let isFuture = date > today
        let state = isFuture ? DayCompletion.noEntries : completion(date)
        let isTappable = !isFuture && !isToday && state != .noEntries

        let circle = ZStack {
            // Today: ring with a gap around the fill, so it still shows on a green (all met) day in dark mode,
            // where the ring and the fill are the same green.
            Circle().fill(fill(for: state))
                .padding(isToday ? 4 : 0)
            if isToday {
                Circle().strokeBorder(Theme.controlPrimary, lineWidth: 2)
            }
            Text(date, format: .dateTime.day())
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(4)
                .foregroundStyle(numberColor(for: state, isFuture: isFuture))
        }
        // 38pt, scaled with text size but never wider than its column, so large text can't overlap days.
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: cellSize)
        .frame(maxWidth: .infinity)

        if isTappable {
            Button { onSelect(date) } label: { circle }
                .buttonStyle(.plain)
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityValue(accessibilityValue(for: state, isToday: isToday))
        } else {
            circle
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityValue(isFuture ? "" : accessibilityValue(for: state, isToday: isToday))
        }
    }

    private func fill(for state: DayCompletion) -> Color {
        switch state {
        case .allMet: Theme.green
        case .someMet: Theme.green.opacity(0.25)
        case .noneMet, .noEntries: .clear
        }
    }

    private func numberColor(for state: DayCompletion, isFuture: Bool) -> Color {
        if isFuture { return Theme.textSecondary }
        return state == .allMet ? Theme.textOnTint : Theme.textPrimary
    }

    private func accessibilityValue(for state: DayCompletion, isToday: Bool) -> String {
        let status = switch state {
        case .allMet: "All goals met"
        case .someMet: "Some goals met"
        case .noneMet: "No goals met"
        case .noEntries: "Nothing logged"
        }
        return isToday ? "Today, \(status)" : status
    }

    private var legend: some View {
        // One row normally; stacked when large text no longer fits it.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { legendItems }
            VStack(alignment: .leading, spacing: 6) { legendItems }
        }
        .font(.footnote)
        .foregroundStyle(Theme.textSecondary)
        .accessibilityHidden(true)  // each day already says its state
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem("All goals") { Circle().fill(Theme.green) }
        legendItem("Some") { Circle().fill(Theme.green.opacity(0.25)) }
        legendItem("Today") { Circle().strokeBorder(Theme.controlPrimary, lineWidth: 1.5) }
    }

    private func legendItem(_ title: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 6) {
            swatch().frame(width: 10, height: 10)
            Text(title).fixedSize()
        }
    }
}

private struct MonthCalendarPreview: View {
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        MonthCalendar(
            grid: MonthGrid(containing: today),
            today: today,
            completion: { date in
                let offset = calendar.dateComponents([.day], from: date, to: today).day ?? 0
                return offset == 0 ? .someMet : (offset % 9 == 0 ? .someMet : (offset % 13 == 0 ? .noEntries : .allMet))
            },
            canShowPrevious: true, canShowNext: false,
            onPrevious: {}, onNext: {}, onSelect: { _ in }
        )
        .padding(18)
        .cardStyle()
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") { MonthCalendarPreview() }
#Preview("Dark") { MonthCalendarPreview().preferredColorScheme(.dark) }
