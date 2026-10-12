import SwiftUI
import SwiftData

/// History tab (DESIGN.md §5.4): streak card, month calendar, and the most recent days. Tapping a past day — in
/// the calendar or the list — pushes `HistoryDayView`.
struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = HistoryViewModel()
    @State private var selectedDay: Date?

    private var streaksEnabled: Bool { allPreferences.first?.streaksEnabled != false }

    var body: some View {
        Group {
            if let log = viewModel.log {
                if log.hasPastEntries {
                    content(log)
                } else {
                    emptyState
                }
            } else {
                Theme.surfaceGround.ignoresSafeArea()
            }
        }
        .navigationDestination(item: $selectedDay) { date in
            HistoryDayView(date: date, viewModel: viewModel)
        }
        .onAppear {
            viewModel.refresh(context: modelContext)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No History Yet", systemImage: "calendar")
        } description: {
            Text("Your past days will appear here once a day with logged intake is over.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }

    private func content(_ log: HistoryLog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap + 2) {
                if streaksEnabled, let streak = viewModel.streak, streak.current > 0 || streak.best > 0 {
                    StreakCard(current: streak.current, best: streak.best)
                }

                MonthCalendar(
                    grid: viewModel.month,
                    today: log.today,
                    completion: { log.day($0).completion },
                    canShowPrevious: viewModel.canShowPreviousMonth,
                    canShowNext: viewModel.canShowNextMonth,
                    onPrevious: { viewModel.showPreviousMonth() },
                    onNext: { viewModel.showNextMonth() },
                    onSelect: { selectedDay = $0 }
                )
                .padding(Theme.Spacing.cardPadding + 4)
                .cardStyle()

                if !viewModel.recentDays.isEmpty {
                    Text("Recent days")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)

                    VStack(spacing: 0) {
                        ForEach(viewModel.recentDays) { day in
                            RecentDayRow(day: day, tints: day.goals.map { viewModel.nutrient($0.nutrientID)?.tint ?? .green }) {
                                selectedDay = day.date
                            }
                            if day.id != viewModel.recentDays.last?.id {
                                Divider().overlay(Theme.lineHairline)
                                    .padding(.leading, Theme.Spacing.cardPadding + 4)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .background(Theme.surfaceGround)
        .refreshable { viewModel.refresh(context: modelContext) }
    }
}

/// "Sunday, 11 October", a dot per goal (tint if met, chip if not), the score and a chevron.
private struct RecentDayRow: View {
    let day: HistoryDay
    /// Tint per goal, in the same order as `day.goals`.
    let tints: [NutrientTint]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 5) {
                        ForEach(Array(zip(day.goals, tints)), id: \.0.id) { goal, tint in
                            Circle()
                                .fill(goal.isMet ? tint.color : Theme.surfaceChip)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                Text("\(day.metCount)/\(day.goals.count)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(day.completion == .allMet ? Theme.textGreenInk : Theme.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.cardPadding + 4)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(HistoryText.goalsLine(met: day.metCount, total: day.goals.count) + " met")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Light") {
    NavigationStack {
        HistoryListView()
            .navigationTitle("History")
    }
    .modelContainer(previewContainer)
}

#Preview("Dark") {
    NavigationStack {
        HistoryListView()
            .navigationTitle("History")
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
