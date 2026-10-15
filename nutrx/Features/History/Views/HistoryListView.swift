import SwiftUI
import SwiftData

/// History tab (DESIGN.md §5.4): streak card, the weekly recaps row (nutrx Pro), month calendar, and the most recent
/// days. Tapping a past day — in the calendar or the list — pushes `HistoryDayView`; the recaps row (or a recap
/// notification) pushes `WeeklyRecapView`.
struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = HistoryViewModel()
    @State private var selectedDay: Date?
    @State private var showRecap = false
    /// A new value rebuilds the recap screen, so a notification opens the newest week even over an older one.
    @State private var recapID = UUID()
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(ProAccess.self) private var proAccess: ProAccess?

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
        .navigationDestination(isPresented: $showRecap) {
            WeeklyRecapView().id(recapID)
        }
        .onAppear {
            viewModel.refresh(context: modelContext)
            openRecapIfAsked()
        }
        .onChange(of: router?.showsRecap) { openRecapIfAsked() }
        .onChange(of: scenePhase) { _, phase in
            // Back from the background, possibly on a new day: move today's ring and pick up synced entries.
            if phase == .active { viewModel.refresh(context: modelContext) }
        }
    }

    /// A tapped recap notification (the tab bar has already switched here) — still Pro only: one left in
    /// Notification Center doesn't open the recap after Pro has lapsed.
    private func openRecapIfAsked() {
        guard router?.showsRecap == true else { return }
        router?.showsRecap = false
        Task {
            // A tap can cold-launch the app before the entitlement is known.
            if let proAccess, !proAccess.hasCheckedEntitlements { await proAccess.refreshEntitlement() }
            guard ProAccess.isStoreVisible, proAccess?.isPro == true else { return }
            selectedDay = nil
            recapID = UUID()
            showRecap = true
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

                if ProAccess.isStoreVisible {
                    RecapRow(latest: viewModel.latestRecap) { showRecap = true }
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
                        .font(.headline.weight(.bold))  // 17pt bold over 16pt semibold rows (History.dc.html)
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

/// "Weekly recaps" (docs/pro/design/5-weekly-recap: history): the latest week's line for Pro, or the PRO chip and
/// "A short summary of each week" for free users (the paywall).
private struct RecapRow: View {
    let latest: WeeklyRecap?
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ProGatedButton(action: onOpen) { showsBadge in
            HStack(spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize {
                    NutrientIconTile(tint: .indigo, symbolName: "calendar", size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Weekly recaps")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if showsBadge { ProBadge() }
                    }
                    Text(showsBadge ? "A short summary of each week"
                         : latest.map { RecapText($0).historyLine } ?? RecapText.firstTitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.cardPadding)
            .cardStyle()
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
        .buttonStyle(.plain)
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
                        .font(.callout.weight(.semibold))  // 16pt semibold (History.dc.html)
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
