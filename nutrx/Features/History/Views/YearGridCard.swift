import SwiftUI

/// History's year of full days (DESIGN.md §4.9a), GitHub's contribution grid: "142 full days in the last year" over a
/// square per day, coloured as the calendar's circles, scrolled to this week (swipe back for earlier). The squares are
/// too small to open, so a tap picks a day and the line under the grid reads it; tapping that line opens a past day.
struct YearGridCard: View {
    let grid: YearGrid
    let completion: (Date) -> DayCompletion
    let fullDays: Int
    /// "Tue, 4 Nov · 3 of 4 goals" for the picked day.
    let dayLine: (Date) -> String
    /// Whether a day opens (a past day with something logged), as in the calendar.
    let canOpen: (Date) -> Bool
    let onOpen: (Date) -> Void

    @State private var picked: Date?
    /// Weeks off the leading edge: the scroll view isn't at the first week.
    @State private var hasEarlierWeeks = false

    static let cell: CGFloat = 12
    static let gap: CGFloat = 3
    private static var pitch: CGFloat { cell + gap }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HistoryText.fullDaysInLastYear(fullDays))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        monthLabels
                        squares
                    }
                    // Room for the picked square's ring, which stands 3 pt out, in the first and last column and row.
                    .padding(.horizontal, 3)
                    .padding(.bottom, 3)
                }
                .defaultScrollAnchor(.trailing)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                // The column cut at the leading edge fades out, so it reads as more weeks that way, not a clipped one;
                // scrolled back to the first week, nothing is cut and nothing fades.
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.x > 1 } action: { _, scrolled in
                    hasEarlierWeeks = scrolled
                }
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [hasEarlierWeeks ? .clear : .black, .black],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                        Color.black
                    }
                }
            }
            // The labels sit in fixed 12 pt rows: they stop growing where they'd overlap.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            // VoiceOver can't pick a 12 pt square: the title gives the count, and the calendar below opens each day.
            .accessibilityHidden(true)

            footer
        }
        .padding(Theme.Spacing.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Grid

    private var weekdayLabels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Jan").font(.caption2).hidden()  // the month row's height
            VStack(alignment: .leading, spacing: Self.gap) {
                ForEach(grid.weekdaySymbols.indices, id: \.self) { row in
                    Text(grid.labelledRows.contains(row) ? grid.weekdaySymbols[row] : "")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                        .frame(height: Self.cell)
                }
            }
        }
    }

    /// Each month's name over the week holding its 1st; in the last two weeks it ends at the grid's edge instead of
    /// running past it.
    private var monthLabels: some View {
        let width = CGFloat(grid.weeks.count) * Self.pitch - Self.gap
        return ZStack(alignment: .topLeading) {
            Text(verbatim: "Jan").font(.caption2).hidden()
            ForEach(Array(grid.weeks.enumerated()), id: \.element.id) { index, week in
                if let label = week.monthLabel {
                    let nearEnd = index >= grid.weeks.count - 2
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                        .frame(width: nearEnd ? width : nil, alignment: .trailing)
                        .offset(x: nearEnd ? 0 : CGFloat(index) * Self.pitch)
                }
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private var squares: some View {
        HStack(alignment: .top, spacing: Self.gap) {
            ForEach(grid.weeks) { week in
                VStack(spacing: Self.gap) {
                    ForEach(week.days.indices, id: \.self) { row in
                        if let day = week.days[row] {
                            square(day)
                        } else {
                            Color.clear.frame(width: Self.cell, height: Self.cell)
                        }
                    }
                }
            }
        }
        // One tap target for the whole grid, gaps included: the square under the finger.
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            pick(at: location)
        }
    }

    private func square(_ day: Date) -> some View {
        let state = completion(day)
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        return shape
            .fill(Self.fill(for: state))
            .overlay {
                if state == .rest { shape.strokeBorder(Theme.surfaceChip, lineWidth: 1.5) }
            }
            .overlay {
                if day == grid.today { shape.strokeBorder(Theme.controlPrimary, lineWidth: 1.5) }
            }
            .frame(width: Self.cell, height: Self.cell)
            .overlay {
                if day == picked {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .strokeBorder(Theme.textPrimary, lineWidth: 2)
                        .padding(-3)
                }
            }
    }

    private func pick(at location: CGPoint) {
        let column = Int(location.x / Self.pitch)
        let row = Int(location.y / Self.pitch)
        guard grid.weeks.indices.contains(column), (0..<7).contains(row),
              let day = grid.weeks[column].days[row] else { return }
        picked = picked == day ? nil : day
    }

    /// As the calendar's circles (§4.9), with the empty days told apart: a day logged with nothing met is a shade
    /// darker than a day with nothing logged.
    static func fill(for state: DayCompletion) -> Color {
        switch state {
        case .allMet: Theme.green
        case .someMet: Theme.green.opacity(0.4)
        case .noneMet: Theme.surfaceChip
        case .noEntries: Theme.surfaceChip.opacity(0.45)
        case .rest: .clear
        }
    }

    // MARK: - Footer

    /// The picked day's line, or the legend.
    @ViewBuilder
    private var footer: some View {
        if let picked {
            if canOpen(picked) {
                Button { onOpen(picked) } label: { pickedLine(picked, opens: true) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the day")
            } else {
                pickedLine(picked, opens: false)
            }
        } else {
            legend
        }
    }

    private func pickedLine(_ day: Date, opens: Bool) -> some View {
        HStack(spacing: 8) {
            Text(dayLine(day))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 22)
        .contentShape(Rectangle())
    }

    private var legend: some View {
        // One row normally; stacked when large text no longer fits it.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { legendItems }
            VStack(alignment: .leading, spacing: 6) { legendItems }
        }
        .font(.footnote)
        .foregroundStyle(Theme.textSecondary)
        .frame(minHeight: 22)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem("All goals", state: .allMet)
        legendItem("Some", state: .someMet)
        legendItem("None", state: .noneMet)
    }

    private func legendItem(_ title: String, state: DayCompletion) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Self.fill(for: state))
                .frame(width: 10, height: 10)
            Text(title).fixedSize()
        }
    }
}

private struct YearGridCardPreview: View {
    var body: some View {
        let calendar = Calendar.current
        let grid = YearGrid(today: .now)
        YearGridCard(
            grid: grid,
            completion: { date in
                let offset = calendar.dateComponents([.day], from: date, to: grid.today).day ?? 0
                if offset > 200 { return .noEntries }
                return offset % 11 == 0 ? .noneMet : (offset % 5 == 0 ? .someMet : .allMet)
            },
            fullDays: 142,
            dayLine: { HistoryText.yearDayLine(date: $0, completion: .someMet, met: 3, total: 4, isToday: false) },
            canOpen: { _ in true },
            onOpen: { _ in }
        )
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") { YearGridCardPreview() }
#Preview("Dark") { YearGridCardPreview().preferredColorScheme(.dark) }
