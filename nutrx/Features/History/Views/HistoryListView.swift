import SwiftUI
import SwiftData

/// History tab (DESIGN.md §5.4): streak card, the weekly recaps row (nutrx Pro), month calendar, and the most recent
/// days. Tapping a past day — in the calendar or the list — pushes `HistoryDayView`, and the recaps row (or a recap
/// notification) pushes `WeeklyRecapView`; in the large-screen split view (#154) both open in the detail instead.
struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = HistoryViewModel()
    @State private var selectedDay: Date?
    @State private var showRecap = false
    @State private var showReport = false
    @State private var showExport = false
    @State private var showPaywall = false
    /// A new value rebuilds the recap screen, so a notification opens the newest week even over an older one.
    @State private var recapID = UUID()
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(\.widthClass) private var widthClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isPreparingSplitViews) private var isPreparingSplitViews

    /// A split view from regular widths (docs/design/large-screens/LAYOUT.md, #154): the calendar and the rest of
    /// History in the sidebar, the selected day beside it. As in My Nutrients, only where the system shows both
    /// columns: a landscape iPhone (compact size class) keeps the push.
    private var usesSplitView: Bool {
        guard widthClass != .compact, horizontalSizeClass == .regular else { return false }
        // From AX1 on regular widths (under 1000 pt) the panes are too narrow for the text: a stack (#155).
        return !(dynamicTypeSize.isAccessibilitySize && widthClass == .regular)
    }

    private var streaksEnabled: Bool { allPreferences.first?.streaksEnabled != false }

    var body: some View {
        Group {
            if usesSplitView {
                NavigationSplitView {
                    historyPage
                        .navigationSplitViewColumnWidth(widthClass == .wide ? 380 : 340)
                } detail: {
                    NavigationStack {
                        dayDetail
                            // The recap opens over the day, in the detail.
                            .navigationDestination(isPresented: $showRecap) {
                                WeeklyRecapView().id(recapID)
                            }
                    }
                }
            } else {
                NavigationStack {
                    historyPage
                        .navigationDestination(item: $selectedDay) { date in
                            HistoryDayView(date: date, viewModel: viewModel)
                        }
                        .navigationDestination(isPresented: $showRecap) {
                            WeeklyRecapView().id(recapID)
                        }
                }
            }
        }
        // A window narrowed to compact with the recap open in the detail: keep just the recap, or the stack would
        // push the day and the recap on top of it, which the user never stacked.
        .onChange(of: usesSplitView) { _, split in
            if !split, showRecap { selectedDay = nil }
        }
    }

    /// Opens a day: pushed on iPhone; in the split view's detail, closing a recap open there, even when it's the day
    /// already selected (a change of `selectedDay` alone missed that).
    private func select(_ day: Date) {
        if usesSplitView { showRecap = false }
        selectedDay = day
    }

    /// The split view's detail: the selected day, or "Pick a day".
    @ViewBuilder
    private var dayDetail: some View {
        if let selectedDay {
            HistoryDayView(date: selectedDay, viewModel: viewModel)
                .id(selectedDay)
        } else if viewModel.log?.hasPastEntries == true {
            SplitDetailPlaceholder(
                systemImage: "calendar",
                title: "Pick a day",
                message: "Choose a day in the calendar to see which goals you met and what you logged."
            )
        } else {
            // No past days yet: the sidebar says "No History Yet" and has no calendar to pick from.
            Theme.surfaceGround.ignoresSafeArea()
        }
    }

    private var historyPage: some View {
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
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        // Before the report button's toolbar, so the avatar keeps the far-right spot it has on every tab.
        .withProfileMenu()
        .toolbar {
            // Your data (#103): the report and Export data, beside the profile avatar. Export works from the first
            // entry (All time includes today), so the menu shows even before History has a past day; the report
            // needs one.
            if viewModel.hasEntries {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if ProAccess.isStoreVisible, viewModel.hasPastEntries {
                            Button {
                                openReport()
                            } label: {
                                Label("Report for your doctor", systemImage: "doc.text")
                                if proAccess?.isPro != true { Text("nutrx Pro") }
                            }
                        }
                        Button {
                            showExport = true
                        } label: {
                            Label("Export data", systemImage: "tablecells")
                            Text("Your log as a CSV file")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Your data")
                }
            }
        }
        .sheet(isPresented: $showReport) {
            NavigationStack {
                ReportView(showsCancel: true)
            }
        }
        .sheet(isPresented: $showExport) {
            NavigationStack {
                ExportDataView(showsDone: true)
            }
        }
        .proPaywall(isPresented: $showPaywall)
        .onAppear {
            viewModel.refresh(context: modelContext)
            openRecapIfAsked()
        }
        .onChange(of: router?.showsRecap) { openRecapIfAsked() }
        #if DEBUG
        .onChange(of: router?.screenshotRoute, initial: true) { _, route in
            if case .historyDay(let day) = route { select(day) }
        }
        #endif
        // Shown during the launch visit to the split-view tabs: the recap opens once that's over and the tab bar
        // has come here.
        .onChange(of: isPreparingSplitViews) { _, preparing in
            if !preparing { openRecapIfAsked() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from the background, possibly on a new day: move today's ring and pick up synced entries.
            if phase == .active { viewModel.refresh(context: modelContext) }
        }
    }

    /// The report for a Pro user, the paywall otherwise (the menu can't use `ProGatedButton`). Right after launch a
    /// Pro user isn't known yet, so it waits for the first check rather than show the paywall to someone who paid.
    private func openReport() {
        Task {
            if let proAccess, !proAccess.hasCheckedEntitlements { await proAccess.refreshEntitlement() }
            if proAccess?.isPro == true { showReport = true } else { showPaywall = true }
        }
    }

    /// A tapped recap notification (the tab bar has already switched here) — still Pro only: one left in
    /// Notification Center doesn't open the recap after Pro has lapsed.
    private func openRecapIfAsked() {
        guard router?.showsRecap == true, !isPreparingSplitViews else { return }
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
                    onSelect: { select($0) },
                    selected: usesSplitView ? selectedDay : nil
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
                                select(day.date)
                            }
                            if day.id != viewModel.recentDays.last?.id {
                                Divider().overlay(Theme.lineHairline)
                                    .padding(.leading, Theme.Spacing.cardPadding + 4)
                            }
                        }
                    }
                    .cardStyle()
                }

                YourDataCard(onReport: { showReport = true }, onExport: { showExport = true })
                    .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .background(Theme.surfaceGround)
        .refreshable { viewModel.refresh(context: modelContext) }
    }
}

/// "Your data" (#103): the report for your doctor (Pro: the PRO chip and the paywall for free users) and Export data,
/// moved here from Settings.
private struct YourDataCard: View {
    let onReport: () -> Void
    let onExport: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
            Text("Your data")
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                if ProAccess.isStoreVisible {
                    ProGatedButton(action: onReport) { showsBadge in
                        row(title: "Report for your doctor", subtitle: "A PDF of any period", tint: .blue,
                            symbol: "doc.text", showsBadge: showsBadge)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.lineHairline)
                        .padding(.leading, Theme.Spacing.cardPadding + 4 + (dynamicTypeSize.isAccessibilitySize ? 0 : 54))
                }
                Button(action: onExport) {
                    row(title: "Export data", subtitle: "Your log as a CSV file", tint: .green, symbol: "tablecells",
                        showsBadge: false)
                }
                .buttonStyle(.plain)
            }
            .cardStyle()
        }
    }

    private func row(title: String, subtitle: String, tint: NutrientTint, symbol: String,
                     showsBadge: Bool) -> some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                NutrientIconTile(tint: tint, symbolName: symbol, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if showsBadge { ProBadge() }
                }
                Text(subtitle)
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
        // The same insets as the Recent days rows above, so the chevrons line up.
        .padding(.horizontal, Theme.Spacing.cardPadding + 4)
        .padding(.vertical, Theme.Spacing.cardPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
    HistoryListView()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    HistoryListView()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
