import SwiftUI
import SwiftData

/// One past day (DESIGN.md §5.5): weekday caption + date title, a summary card with the day ring and who was
/// missed, then a row per nutrient. Tapping a row shows that day's entries.
struct HistoryDayView: View {
    let date: Date
    let viewModel: HistoryViewModel

    @State private var selectedNutrient: Nutrient?
    @State private var headerScrolledAway = false

    var body: some View {
        let day = viewModel.day(date)

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
                header
                    .padding(.bottom, 8)

                if let day {
                    if !day.goals.isEmpty {
                        summary(day)
                            .padding(.bottom, 4)
                    }

                    ForEach(day.goals) { goal in
                        row(goal, showsStatus: true)
                    }

                    if !day.otherLogged.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Also logged")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text("Removed or excluded that day, so not counted.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)

                        ForEach(day.otherLogged) { goal in
                            row(goal, showsStatus: false)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 60
        } action: { _, scrolledAway in
            headerScrolledAway = scrolledAway
        }
        .background(Theme.surfaceGround)
        // The header carries the date; the bar only shows it once the header has scrolled away.
        .navigationTitle(headerScrolledAway ? date.formatted(.dateTime.day().month(.wide)) : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedNutrient) { nutrient in
            DayEntriesSheet(nutrient: nutrient, date: date, viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
            Text(date, format: .dateTime.day().month(.wide))
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func summary(_ day: HistoryDay) -> some View {
        let missed = day.goals.filter { !$0.isMet }.compactMap { viewModel.nutrient($0.nutrientID)?.name }

        return HStack(spacing: 18) {
            SegmentedDayRing(met: day.metCount, total: day.goals.count, style: .onSurface,
                             lineWidth: 64 * 14 / 116, showsLabel: false)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(HistoryText.goalsLine(met: day.metCount, total: day.goals.count))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(HistoryText.missedLine(missedNames: missed, goalCount: day.goals.count))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.cardPadding + 4)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func row(_ goal: HistoryDay.Goal, showsStatus: Bool) -> some View {
        if let nutrient = viewModel.nutrient(goal.nutrientID) {
            HistoryNutrientRow(nutrient: nutrient, total: goal.total, isMet: showsStatus ? goal.isMet : nil) {
                selectedNutrient = nutrient
            }
        }
    }
}

/// Icon tile, name, "**4,000** / 4,000 IU", an 8pt bar in the tint, and a met / missed badge.
private struct HistoryNutrientRow: View {
    let nutrient: Nutrient
    let total: Double
    /// nil hides the badge (nutrients that didn't count that day).
    let isMet: Bool?
    let onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let progress = GoalProgress(nutrient: nutrient, current: total)

        Button(action: onTap) {
            HStack(spacing: 14) {
                NutrientIconTile(nutrient: nutrient, size: 40)

                VStack(alignment: .leading, spacing: 8) {
                    let nameAndValue = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                    nameAndValue {
                        Text(nutrient.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                        Text("\(Text(progress.currentText).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Theme.textPrimary)) \(Text(progress.goalText).font(.subheadline).foregroundStyle(Theme.textSecondary))")
                            .monospacedDigit()
                    }
                    TintBar(fraction: progress.ringFraction, tint: nutrient.tint)
                }

                if let isMet {
                    StatusBadge(isMet: isMet)
                }
            }
            .padding(Theme.Spacing.cardPadding + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrient.name)
        .accessibilityValue(isMet.map { "\(progress.progressText), \($0 ? "goal met" : "goal missed")" } ?? progress.progressText)
        .accessibilityHint("Shows the day's entries")
        .accessibilityAddTraits(.isButton)
    }
}

/// 8pt rounded bar: the tint over a chip-coloured track.
private struct TintBar: View {
    let fraction: Double
    let tint: NutrientTint

    var body: some View {
        Capsule()
            .fill(Theme.surfaceChip)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(tint.color)
                        // A sliver for anything logged at all, so 1% doesn't vanish.
                        .frame(width: fraction > 0 ? max(geo.size.width * fraction, 8) : 0)
                }
            }
            .accessibilityHidden(true)
    }
}

/// Green check when the goal was met, grey dash when it wasn't.
private struct StatusBadge: View {
    let isMet: Bool

    var body: some View {
        Image(systemName: isMet ? "checkmark" : "minus")
            .font(.caption.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the 28pt circle doesn't grow with text
            .foregroundStyle(isMet ? Theme.textOnTint : Theme.textSecondary)
            .frame(width: 28, height: 28)
            .background(isMet ? Theme.green : Theme.surfaceChip, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The day's entries for one nutrient: time, tint dot, signed amount and note, plus the day's total.
private struct DayEntriesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let nutrient: Nutrient
    let date: Date
    let viewModel: HistoryViewModel

    @State private var records: [IntakeRecord] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if records.isEmpty {
                        Text("Nothing logged that day.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(records, id: \.persistentModelID) { record in
                                entryRow(record)
                                if record.persistentModelID != records.last?.persistentModelID {
                                    Divider().overlay(Theme.lineHairline)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.cardPadding + 2)
                        .cardStyle()

                        let total = max(0, records.reduce(0) { $0 + $1.amount })
                        Text("Total \(total.formattedAmount()) \(nutrient.unit)")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(Theme.Spacing.screenMargin)
            }
            .background(Theme.surfaceGround)
            .navigationTitle(nutrient.name)
            .navigationSubtitle(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            records = viewModel.intakeRecords(for: nutrient, on: date, context: modelContext)
        }
    }

    private func entryRow(_ record: IntakeRecord) -> some View {
        let isDecrement = record.amount < 0
        let signedAmount = "\(isDecrement ? "−" : "+")\(abs(record.amount).formattedAmount(maxFractionDigits: 6)) \(nutrient.unit)"

        return HStack(spacing: 12) {
            Text(record.date, format: .dateTime.hour().minute())
                .font(.system(.subheadline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)

            Circle()
                .fill(nutrient.tint.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(signedAmount)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isDecrement ? Theme.textSecondary : Theme.textPrimary)
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryDayPreview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HistoryViewModel()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            if loaded, let day = viewModel.recentDays.last {
                HistoryDayView(date: day.date, viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.refresh(context: modelContext)
            loaded = true
        }
    }
}

#Preview("Light") {
    HistoryDayPreview()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    HistoryDayPreview()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
