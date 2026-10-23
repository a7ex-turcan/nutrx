import SwiftUI

/// Today's collapsed section of running nutrients that aren't due today (schedules, #132, docs/pro/SCHEDULES.md §5):
/// a header like My Nutrients' Finished, then one card with a row per nutrient and when it's next due. Tapping a row
/// opens the log sheet, to log it anyway; that log is kept but doesn't count.
struct NotTodaySection: View {
    let items: [TodayViewModel.NotTodayItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onLog: (Nutrient) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isExpanded {
                card
            }
        }
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack {
                Text(ScheduleText.notTodayTitle)
                    .font(.footnote.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .accessibilityHidden(true)
                Spacer()
                Text("\(items.count)")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(minHeight: Theme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ScheduleText.notTodayTitle), \(items.count == 1 ? "1 nutrient" : "\(items.count) nutrients")")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                if item.id != items.first?.id {
                    Divider()
                        .overlay(Theme.lineHairline)
                        .padding(.leading, Theme.Spacing.cardPadding + 36 + 12)
                }
                row(item)
            }
        }
        .cardStyle()
    }

    private func row(_ item: TodayViewModel.NotTodayItem) -> some View {
        let next = ScheduleText().next(item.nextDue, today: .now)
        return Button { onLog(item.nutrient) } label: {
            HStack(spacing: 12) {
                NutrientIconTile(tint: item.nutrient.tint, symbolName: item.nutrient.symbolName, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.nutrient.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(next)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.cardPadding)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the log sheet, to log it anyway")
    }
}
