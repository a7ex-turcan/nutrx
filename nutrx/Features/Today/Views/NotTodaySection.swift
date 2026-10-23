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
        let next = item.isWeekDone ? ScheduleText.doneThisWeek : ScheduleText().next(item.nextDue, today: .now)
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

private struct NotTodaySectionPreview: View {
    @State private var isExpanded: Bool

    init(isExpanded: Bool) { _isExpanded = State(initialValue: isExpanded) }

    private var items: [TodayViewModel.NotTodayItem] {
        let today = Calendar.current.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: today)! }
        func nutrient(_ name: String, _ tint: NutrientTint, _ symbol: String) -> Nutrient {
            let nutrient = Nutrient(name: name, unit: "mg", step: 1, dailyTarget: 1, sortOrder: 0)
            nutrient.tint = tint
            nutrient.symbolName = symbol
            return nutrient
        }
        return [
            .init(nutrient: nutrient("Vitamin D", .amber, "sun.max"), total: 0, nextDue: day(2)),
            .init(nutrient: nutrient("Omega-3", .teal, "fish"), total: 0, nextDue: day(1)),
            .init(nutrient: nutrient("Iron", .coral, "drop"), total: 0, nextDue: day(10)),
        ]
    }

    var body: some View {
        ScrollView {
            NotTodaySection(items: items, isExpanded: isExpanded, onToggle: { isExpanded.toggle() }, onLog: { _ in })
                .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
    }
}

#Preview("Expanded") { NotTodaySectionPreview(isExpanded: true) }
#Preview("Collapsed") { NotTodaySectionPreview(isExpanded: false) }
#Preview("Expanded, dark") { NotTodaySectionPreview(isExpanded: true).preferredColorScheme(.dark) }
#Preview("Largest text") { NotTodaySectionPreview(isExpanded: true).dynamicTypeSize(.accessibility5) }
