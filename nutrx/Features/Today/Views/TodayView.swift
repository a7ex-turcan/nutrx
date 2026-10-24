import Combine
import CoreData
import SwiftUI
import WidgetKit
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widthClass) private var widthClass
    /// Today's own width, which picks between the columns and the side column (`TodayLayout`); nil until measured.
    @State private var measuredWidth: CGFloat?
    /// The first nutrient card on screen, so a layout change (rotation, a resized window, unfolding) keeps it at
    /// the top (#198). It only moves while the layout is settled: mid-switch, cards vanishing and the new layout's
    /// first cards appearing would overwrite it.
    @State private var visibleCardIDs: Set<PersistentIdentifier> = []
    @State private var anchorID: PersistentIdentifier?
    @State private var settledLayout: TodayLayout?
    /// Where the day-score card is as Today scrolls, for its collapsing copy (#243).
    @State private var scoreCardTracker = DayScoreCardTracker()

    /// Until Today has measured itself, a guess from the window's class, so an iPad's first frame doesn't build the
    /// iPhone list and then swap it for the grid.
    private var width: CGFloat {
        if let measuredWidth { return measuredWidth }
        switch widthClass {
        case .compact: return 0
        case .regular: return WidthClass.regularMinimum
        case .wide: return TodayLayout.sideColumnMinimum
        }
    }
    /// Set by a card's "Refilled?"; confirmed before the count restarts.
    @State private var nutrientToRefill: Nutrient?
    /// Last week's recap, for the "Your week" card (nutrx Pro): Sunday 18:00 through Monday.
    @State private var weekRecap: WeeklyRecap?
    @State private var showRecap = false
    @AppStorage("nutrx.hidesStackSuggestion") private var hidesStackSuggestion = false
    @State private var showNewStack = false
    @State private var newStackName = ""
    @AppStorage("nutrx.dismissedRecapWeek") private var dismissedRecapWeek: Double = 0
    /// The release whose "What's new" card was closed, or seen at onboarding, on this device (#148).
    @AppStorage(WhatsNew.hiddenVersionKey) private var whatsNewHiddenVersion = ""
    /// Apple Health insights (#102): the status, and whether its Today card was hidden while gathering / once ready.
    @State private var healthStatus: HealthInsights.Status?
    /// Bumped on every appearance, so the Health status is read again after connecting elsewhere (Settings, analytics).
    @State private var healthRefreshTick = 0
    @AppStorage(HealthInsights.TodayCard.hiddenGatheringKey) private var hidesInsightsGatheringCard = false
    @AppStorage(HealthInsights.TodayCard.hiddenReadyKey) private var hidesInsightsReadyCard = false
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Query private var allPreferences: [UserPreferences]
    @Query private var allGroups: [NutrientGroup]
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    @State private var viewModel = TodayViewModel()
    @State private var nutrientToLog: Nutrient?
    /// Whether the Not today section is open (schedules, #132); per device, collapsed by default.
    @AppStorage("nutrx.showsNotToday") private var showsNotToday = false
    @State private var nutrientToEdit: Nutrient?
    @State private var nutrientToMove: Nutrient?
    @State private var editDraft = NutrientDraft()
    @State private var showBanner = false
    @State private var showSyncBanner = false
    @State private var syncBannerVariant: SyncBannerView.Variant = .enabled
    @State private var streak: StreakResult?
    @State private var notificationsAllowed = false
    @State private var showAddSheet = false
    @State private var showPaywall = false
    @State private var showEnjoyPro = false
    @State private var addDraft = NutrientDraft()
    @State private var selectedGroupForAdd: NutrientGroup?
    @AppStorage("wasSyncRestored") private var wasSyncRestored = false
    @State private var stackToLog: LogStack?
    /// A stack's detail, opened from Make a stack or the log sheet's "Edit stack" (the list is the Stacks tab).
    @State private var stackEditing: LogStack?
    /// Set by the log sheet's "Edit stack"; opened once that sheet is gone.
    @State private var pendingStackEdit: LogStack?

    /// Stacks with something to log; an empty one only shows in the Stacks tab.
    private var stacksToShow: [LogStack] {
        stacks.filter { !StackLogging.dueEntries(of: $0).isEmpty }
    }

    private var hasCustomGroups: Bool {
        allGroups.contains(where: { !$0.isSystem })
    }

    private var preferences: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    /// The Health card's status, when it should show (`HealthInsights.TodayCard.visible`).
    private var visibleHealthStatus: HealthInsights.Status? {
        var hidden: Set<HealthInsights.TodayCard.Hidden> = []
        if hidesInsightsGatheringCard { hidden.insert(.gathering) }
        if hidesInsightsReadyCard { hidden.insert(.ready) }
        return HealthInsights.TodayCard.visible(healthStatus, isPro: ProAccess.isStoreVisible && proAccess?.isPro == true,
                                                hidden: hidden)
    }

    private func refreshHealthStatus() async {
        guard ProAccess.isStoreVisible, proAccess?.isPro == true else {
            healthStatus = nil
            return
        }
        healthStatus = await HealthInsights.load(context: modelContext)
    }

    private func seeHealthInsights(_ status: HealthInsights.Status) {
        remember(HealthInsights.TodayCard.hiddenBySeeing(status))
        router?.healthNutrientID = HealthInsights.TodayCard.nutrientID(status)
    }

    private func hideHealthCard(_ status: HealthInsights.Status) {
        remember(HealthInsights.TodayCard.hiddenByDismissing(status))
    }

    private func remember(_ hidden: HealthInsights.TodayCard.Hidden?) {
        switch hidden {
        case .gathering: hidesInsightsGatheringCard = true
        case .ready: hidesInsightsReadyCard = true
        case nil: break
        }
    }

    /// The "Your week" card's recap (`RecapSchedule.todayCardWeek`, `RecapViewModel.recap(forWeek:…)`).
    private func refreshWeekRecap() {
        var ignoresWindow = false
        #if DEBUG
        // Checking the card on a weekday: `simctl spawn <UDID> defaults write nutrx-labs.nutrx
        // nutrx.debug.showRecapCard -bool YES` (Debug builds only).
        ignoresWindow = UserDefaults.standard.bool(forKey: "nutrx.debug.showRecapCard")
        #endif
        let week = RecapSchedule.todayCardWeek(
            at: .now, isPro: ProAccess.isStoreVisible && proAccess?.isPro == true,
            dismissedWeek: dismissedRecapWeek > 0 ? Date(timeIntervalSince1970: dismissedRecapWeek) : nil,
            ignoresWindow: ignoresWindow)
        weekRecap = week.flatMap { RecapViewModel.recap(forWeek: $0, context: modelContext) }
    }

    var body: some View {
        // Read here, not only inside the TimelineView below: a read in its closure didn't make Today redraw when the
        // permission check finished after launch or a grant, so the line waited for the next minute or a tab switch
        // (#45).
        let remindersShown = notificationsAllowed
        Group {
            // Only when nothing is running at all: a day with every nutrient off (#132) still shows Today and its
            // Not today section.
            if !viewModel.hasRunningNutrients {
                emptyState
            } else {
                switch layout {
                // iPhone, and the largest text sizes on any width (one column, LAYOUT.md): the list, for its swipe
                // actions.
                case .list: keepsAnchor(.list) { compactList(remindersShown: remindersShown) }
                case .columns: keepsAnchor(.columns) { columnsLayout(remindersShown: remindersShown) }
                case .sideColumn: sideColumnLayout(remindersShown: remindersShown)
                }
            }
        }
        // Once the day-score card reaches the navigation bar, it pins there and collapses into a slim bar as Today
        // scrolls on (#243). Not beside the side column, which keeps the card in view.
        .overlay {
            if collapsesScoreCard {
                // On the card's minute timeline, so the copy drops a passed reminder when the card does.
                TimelineView(.everyMinute) { timeline in
                    CollapsingDayScoreOverlay(tracker: scoreCardTracker, score: viewModel.dayScore,
                                              streak: preferences.streaksEnabled ? streak?.current : nil,
                                              nextReminder: remindersShown
                                                  ? viewModel.nextReminder(after: timeline.date) : nil)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { measuredWidth = $0 }
        .background(Theme.surfaceGround)
        .toolbar {
            // Free / PRO (#101), on the leading side; the profile avatar keeps the trailing one. Left out at
            // accessibility sizes, where the title and date reach up into the bar's row; decided here because the
            // bar caps its items' text size, so the chip itself never sees an accessibility size.
            if !dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .topBarLeading) {
                    PlanChip(showPaywall: $showPaywall, showEnjoy: $showEnjoyPro)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .planChipSheets(showPaywall: $showPaywall, showEnjoy: $showEnjoyPro)
        #if DEBUG
        .onChange(of: router?.screenshotRoute, initial: true) { _, route in
            if route == .paywall { showPaywall = true }
        }
        #endif
        .onAppear {
            viewModel.refresh(context: modelContext)
            refreshBannerVisibility()
            refreshNotificationPermission()
            refreshSyncBannerVisibility()
            refreshStreak()
            refreshWeekRecap()
            healthRefreshTick += 1
        }
        .task(id: "\(scenePhase == .active)-\(proAccess?.isPro == true)-\(healthRefreshTick)") {
            await refreshHealthStatus()
        }
        .onChange(of: proAccess?.isPro) { refreshWeekRecap() }
        // "Make a stack": name it, then open it to add nutrients.
        .alert("New Stack", isPresented: $showNewStack) {
            TextField("Stack name", text: $newStackName)
            Button("Create") {
                let name = newStackName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                if let existing = StackLogging.stack(named: name, in: stacks) {
                    stackEditing = existing
                    return
                }
                let stack = StackLogging.createStack(named: name, context: modelContext)
                StackShortcutLogging.stacksChanged()
                stackEditing = stack
            }
            .disabled(newStackName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(StackLogging.newStackMessage(existing: stacks.map(\.name)))
        }
        .sheet(isPresented: $showRecap) {
            NavigationStack {
                WeeklyRecapView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showRecap = false }
                        }
                    }
            }
        }
        .onChange(of: allGroups.count) {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh(context: modelContext)
                refreshStreak()
                refreshWeekRecap()
                refreshNotificationPermission()
                // Allowed in iOS Settings, or after the system prompt (#44).
                refreshBannerVisibility()
                NotificationService.refreshDailyReminder(context: modelContext)
                viewModel.rescheduleReminders(context: modelContext)
            }
        }
        // Answered the permission prompt somewhere else in the app (Settings → Notifications sits in a sheet over
        // Today, so Today doesn't re-appear when it closes, #44).
        .onReceive(NotificationCenter.default.publisher(for: .notificationPermissionAnswered)
            .receive(on: DispatchQueue.main)) { _ in
            refreshBannerVisibility()
            refreshNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: .intakeLoggedByShortcut).receive(on: DispatchQueue.main)) { _ in
            // A Siri or shortcut log while Today is on screen; the intent already rescheduled reminders.
            viewModel.refresh(context: modelContext)
            refreshStreak()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
            viewModel.refresh(context: modelContext)
            refreshStreak()
            // A log synced from another device silences that nutrient's reminders for today here too.
            viewModel.rescheduleReminders(context: modelContext)
        }
        .sheet(item: $nutrientToLog) { nutrient in
            LogSheet(
                nutrient: nutrient,
                notDueNote: notDueNote(for: nutrient),
                onLog: { amount, note in
                    withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                        viewModel.addCustomAmount(amount, to: nutrient, note: note, context: modelContext)
                    }
                    checkForReview()
                },
                onDelete: { record in
                    viewModel.deleteRecord(record, context: modelContext)
                }
            )
        }
        .sheet(item: $nutrientToEdit) { nutrient in
            NutrientFormView(
                draft: editDraft,
                title: "Edit Nutrient",
                buttonLabel: "Save",
                nutrient: nutrient
            ) {
                applyEdit(to: nutrient)
            }
        }
        .sheet(item: $nutrientToMove) { nutrient in
            MoveToGroupSheet(nutrient: nutrient)
        }
        .confirmationDialog("Refilled \(nutrientToRefill?.name ?? "")?",
                            isPresented: Binding(get: { nutrientToRefill != nil }, set: { if !$0 { nutrientToRefill = nil } }),
                            titleVisibility: .visible) {
            Button("Refilled") {
                nutrientToRefill?.refillSupply()
                try? modelContext.save()
                nutrientToRefill = nil
                viewModel.refresh(context: modelContext)
                NotificationService.refreshAllNutrientReminders(context: modelContext)
                WidgetCenter.shared.reloadAllTimelines()
            }
        } message: {
            Text("Starts the count again from a full bottle.")
        }
        .sheet(item: $stackToLog, onDismiss: {
            if let stack = pendingStackEdit {
                pendingStackEdit = nil
                stackEditing = stack
            }
        }) { stack in
            LogStackSheet(
                stack: stack,
                totalFor: { viewModel.total(for: $0) },
                onLog: { amounts in
                    let result = withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                        viewModel.logStack(stack, amounts: amounts, context: modelContext)
                    }
                    Haptics.logged(reachingGoal: result.reachedGoal)
                    refreshStreak()
                    checkForReview()
                    return result.logged
                },
                onUndo: { logged in
                    withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                        viewModel.undoStack(logged, of: stack, context: modelContext)
                    }
                    refreshStreak()
                },
                onEditStack: { pendingStackEdit = stack }
            )
        }
        .sheet(item: $stackEditing, onDismiss: {
            viewModel.refresh(context: modelContext)
        }) { stack in
            NavigationStack {
                StackDetailView(stack: stack)
                .toolbar {
                    // Leading close, so it never sits next to the detail's own Edit / Done.
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            stackEditing = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NutrientFormView(
                draft: addDraft,
                title: "New Nutrient",
                buttonLabel: "Add",
                selectedGroup: $selectedGroupForAdd,
                showGroupPicker: true,
                offersScan: true
            ) {
                addNutrient()
            }
        }
    }

    // MARK: - Layouts

    private var layout: TodayLayout {
        TodayLayout.of(width: width, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    /// Wraps a layout's scroll view: when it replaces another layout, the anchor card goes back to the top (#198).
    private func keepsAnchor(_ layout: TodayLayout, @ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ScrollViewReader { proxy in
            content
                .onAppear {
                    let switched = settledLayout != nil && settledLayout != layout
                    guard switched, let anchorID else {
                        settledLayout = layout
                        return
                    }
                    Task { @MainActor in
                        // A frame for the new layout to exist before scrolling in it.
                        await Task.yield()
                        // Flipped again meanwhile (a window dragged back and forth): that layout settles itself.
                        guard self.layout == layout else { return }
                        proxy.scrollTo(anchorID, anchor: .top)
                        settledLayout = layout
                    }
                }
                // A tap on the collapsed day score brings the card back (#246). In the columns the card's 8 pt top
                // margin is the content's padding, so that scrolls to the content's top; in the list it's the row's.
                .onChange(of: scoreCardTracker.scrollBackRequests) {
                    withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.35))) {
                        proxy.scrollTo(layout == .columns ? Self.columnsTopID : Self.scoreCardID, anchor: .top)
                    }
                }
        }
    }

    /// Follows which cards are on screen; the anchor is the first of them in Today's order.
    private func cardVisibility(_ id: PersistentIdentifier, visible: Bool) {
        if visible { visibleCardIDs.insert(id) } else { visibleCardIDs.remove(id) }
        guard settledLayout == layout else { return }
        let order = viewModel.groupSections.flatMap { section in
            section.group.isCollapsed ? [] : section.intakes.map(\.nutrient.persistentModelID)
        }
        anchorID = TodayLayout.anchor(in: order, visible: visibleCardIDs)
    }

    private func compactList(remindersShown: Bool) -> some View {
        List {
            dayScoreCard(remindersShown: remindersShown)
                .listRowInsets(EdgeInsets(top: 8, leading: Theme.Spacing.screenMargin,
                                          bottom: Theme.Spacing.cardGap / 2, trailing: Theme.Spacing.screenMargin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Group { todayCards }
                .listRowInsets(cardRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if !stacksToShow.isEmpty {
                stacksRow(.row, margin: Theme.Spacing.screenMargin)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.sectionTop - Theme.Spacing.cardGap / 2,
                                              leading: 0, bottom: Theme.Spacing.cardGap / 2, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(viewModel.groupSections) { section in
                if hasCustomGroups {
                    groupHeader(section)
                        .listRowInsets(EdgeInsets(top: Theme.Spacing.sectionTop - Theme.Spacing.cardGap / 2,
                                                  leading: Theme.Spacing.screenMargin, bottom: 0,
                                                  trailing: Theme.Spacing.screenMargin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if !section.group.isCollapsed {
                    ForEach(section.intakes, id: \.nutrient.persistentModelID) { entry in
                        nutrientCard(entry, inGrid: false)
                            .listRowInsets(cardRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    nutrientToLog = entry.nutrient
                                } label: {
                                    Label("Add Exact Amount", systemImage: "number")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    edit(entry.nutrient)
                                } label: {
                                    Label("Edit Nutrient", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            if !viewModel.notToday.isEmpty {
                // Last on Today: room below it, so it doesn't sit against the tab bar at the bottom.
                notTodaySection
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.sectionTop - Theme.Spacing.cardGap / 2,
                                              leading: Theme.Spacing.screenMargin, bottom: Theme.Spacing.sectionTop,
                                              trailing: Theme.Spacing.screenMargin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // At the largest text sizes on a large screen the list is one 640 pt column (#155); nothing on iPhone.
        .readableColumn()
    }

    // Regular and wide widths (docs/design/large-screens/LAYOUT.md, #152). A grid has no swipe actions: the card's
    // context menu (long press, or a secondary click) has the same ones, and VoiceOver gets "Edit Nutrient" on the
    // card; tapping it opens the log sheet as on iPhone.

    /// The score, cards and stacks in a 360 pt side column that stays in view while the nutrients scroll;
    /// everything capped at 1120 pt and centred, with at least 40 pt margins.
    private func sideColumnLayout(remindersShown: Bool) -> some View {
        HStack(alignment: .top, spacing: TodayLayout.sideColumnGap) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
                    sideColumn(remindersShown: remindersShown)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .frame(width: TodayLayout.sideColumnWidth)
            keepsAnchor(.sideColumn) {
                ScrollView {
                    groupsGrid(gutter: TodayLayout.gutter(.wide))
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: TodayLayout.maxContentWidth)
        .padding(.horizontal, WidthClass.wide.minimumMargin)
        .frame(maxWidth: .infinity)
    }

    /// Everything in one scroll: the score, cards and stack tiles across both columns, then the groups.
    private func columnsLayout(remindersShown: Bool) -> some View {
        // Today's own width, like the layout, not the window's: they differ once Today sits in a split pane.
        let ownClass = WidthClass(width: width)
        let gutter = TodayLayout.gutter(ownClass)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
                dayScoreCard(remindersShown: remindersShown)
                todayCards
                if !stacksToShow.isEmpty {
                    stacksRow(.tiles, margin: 0, gutter: gutter)
                        .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)
                }
                groupsGrid(gutter: gutter)
            }
            .padding(.horizontal, ownClass.minimumMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
            // The very top, margin included, for scrolling back to the day score (#246).
            .background(alignment: .top) { Color.clear.frame(height: 1).id(Self.columnsTopID) }
        }
    }

    @ViewBuilder
    private func sideColumn(remindersShown: Bool) -> some View {
        dayScoreCard(remindersShown: remindersShown)
        todayCards
        if !stacksToShow.isEmpty {
            stacksRow(.list, margin: 0)
                .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)
        }
    }

    /// The groups, each a header across both columns and its cards two to a row, in reading order.
    private func groupsGrid(gutter: CGFloat) -> some View {
        let columns = [GridItem(.flexible(), spacing: gutter, alignment: .top),
                       GridItem(.flexible(), spacing: gutter, alignment: .top)]
        return VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
            ForEach(viewModel.groupSections) { section in
                if hasCustomGroups {
                    groupHeader(section)
                        .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)
                }
                if !section.group.isCollapsed {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.cardGap) {
                        ForEach(section.intakes, id: \.nutrient.persistentModelID) { entry in
                            nutrientCard(entry, inGrid: true)
                        }
                    }
                }
            }
            if !viewModel.notToday.isEmpty {
                notTodaySection
                    .padding(.top, Theme.Spacing.sectionTop - Theme.Spacing.cardGap)
            }
        }
    }

    /// For a nutrient in Not today, the log sheet's line saying the log won't count today (#247).
    private func notDueNote(for nutrient: Nutrient) -> String? {
        viewModel.notToday.first { $0.id == nutrient.persistentModelID }.map {
            ScheduleText().notDueNote(nextDue: $0.nextDue, isWeekDone: $0.isWeekDone, today: .now)
        }
    }

    /// Running nutrients that aren't due today (#132), after the groups; tapping one logs it anyway.
    private var notTodaySection: some View {
        NotTodaySection(items: viewModel.notToday, isExpanded: showsNotToday, onToggle: {
            withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) { showsNotToday.toggle() }
        }, onLog: { nutrientToLog = $0 })
    }

    // MARK: - Pieces

    /// The day-score card, re-evaluated every minute so a reminder drops off once its time passes.
    private func dayScoreCard(remindersShown: Bool) -> some View {
        TimelineView(.everyMinute) { timeline in
            DayScoreCard(
                score: viewModel.dayScore,
                streak: preferences.streaksEnabled ? streak?.current : nil,
                nextReminder: remindersShown ? viewModel.nextReminder(after: timeline.date) : nil
            )
        }
        .tracksDayScoreCard(scoreCardTracker, isActive: collapsesScoreCard)
        .id(Self.scoreCardID)
    }

    private static let scoreCardID = "dayScoreCard"
    private static let columnsTopID = "columnsTop"

    /// The list and the columns collapse the day-score card as they scroll; the side column keeps it in view.
    private var collapsesScoreCard: Bool {
        viewModel.hasRunningNutrients && layout != .sideColumn
    }

    /// This release's "What's new" card, unless it was closed here or onboarding ran on this release (#148). In Debug
    /// builds `simctl spawn <UDID> defaults write nutrx-labs.nutrx nutrx.debug.whatsNewVersion 2.3` pretends to be
    /// that version. To show a closed card again, delete `nutrx.whatsNewHiddenVersion` from the app's own
    /// preferences (`simctl get_app_container <UDID> nutrx-labs.nutrx data` + `/Library/Preferences/nutrx-labs.nutrx`;
    /// plain `defaults delete nutrx-labs.nutrx` misses it).
    private var whatsNew: WhatsNew? {
        var appVersion = Bundle.main.appVersion
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "nutrx.debug.whatsNewVersion") { appVersion = override }
        #endif
        return WhatsNew.card(appVersion: appVersion, hiddenVersion: whatsNewHiddenVersion,
                             isPad: UIDevice.current.userInterfaceIdiom == .pad)
    }

    /// The cards under the day score: what's new, the weekly recap, Apple Health insights, a banner, the stack
    /// suggestion.
    @ViewBuilder
    private var todayCards: some View {
        if let whatsNew {
            WhatsNewTodayCard(whatsNew: whatsNew) {
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    whatsNewHiddenVersion = whatsNew.version
                }
            }
        }

        if let weekRecap {
            RecapTodayCard(recap: weekRecap, onOpen: { showRecap = true }, onDismiss: {
                dismissedRecapWeek = weekRecap.weekStart.timeIntervalSince1970
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    self.weekRecap = nil
                }
            })
        }

        if let healthCard = visibleHealthStatus {
            HealthInsightsTodayCard(status: healthCard, onSeeWhere: {
                seeHealthInsights(healthCard)
            }, onDismiss: {
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    hideHealthCard(healthCard)
                }
            })
        }

        if showBanner {
            NotificationBannerView(
                onEnable: { enableReminder() },
                onDismiss: { dismissBanner() }
            )
        } else if showSyncBanner {
            SyncBannerView(variant: syncBannerVariant) {
                dismissSyncBanner()
            }
        }

        if stacksToShow.isEmpty, StackLogging.suggestsStack(
            nutrientCount: viewModel.groupSections.reduce(0) { $0 + $1.intakes.count },
            stackCount: stacks.count, hidden: hidesStackSuggestion) {
            StackSuggestionCard(
                onMake: {
                    newStackName = ""
                    showNewStack = true
                },
                onHide: {
                    withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                        hidesStackSuggestion = true
                    }
                }
            )
        }
    }

    private func stacksRow(_ layout: StacksRow.Layout, margin: CGFloat, gutter: CGFloat = 16) -> some View {
        StacksRow(
            stacks: stacksToShow,
            layout: layout,
            horizontalMargin: margin,
            tileGutter: gutter,
            onLog: { stackToLog = $0 },
            onEdit: { NotificationRouter.shared.showsStacks = true }
        )
    }

    private func edit(_ nutrient: Nutrient) {
        editDraft.populate(from: nutrient)
        nutrientToEdit = nutrient
    }

    /// 16pt side margins and a 10pt gap between cards.
    private var cardRowInsets: EdgeInsets {
        EdgeInsets(top: Theme.Spacing.cardGap / 2, leading: Theme.Spacing.screenMargin,
                   bottom: Theme.Spacing.cardGap / 2, trailing: Theme.Spacing.screenMargin)
    }

    private func groupHeader(_ section: TodayViewModel.GroupSection) -> some View {
        // As in the day score: an unmet weekly nutrient (#132) isn't a goal of the day.
        let score = DayScore(progresses: section.intakes.filter(\.isGoalToday).map(\.progress))
        return GroupHeader(
            name: section.group.name,
            met: score.met,
            total: score.total,
            isCollapsed: section.group.isCollapsed,
            onToggle: {
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    section.group.isCollapsed.toggle()
                }
            }
        )
    }

    /// Today's supply hint (nutrx Pro): low or out only, so a card's height never changes otherwise.
    private func supplyHint(for nutrient: Nutrient) -> NutrientCard.SupplyHint? {
        guard ProAccess.isStoreVisible, proAccess?.isPro == true, let status = viewModel.supplyStatus(for: nutrient),
              let text = SupplyText.todayHint(status) else { return nil }
        return NutrientCard.SupplyHint(text: text, shortText: SupplyText.shortHint(status),
                                       compactText: SupplyText.compactHint(status), isOut: status.level == .out)
    }

    private func nutrientCard(_ entry: TodayViewModel.NutrientIntake, inGrid: Bool) -> some View {
        NutrientCard(
            nutrient: entry.nutrient,
            currentIntake: entry.total,
            onOpen: {
                nutrientToLog = entry.nutrient
            },
            onIncrement: {
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                    viewModel.increment(entry.nutrient, context: modelContext)
                }
                checkForReview()
            },
            onDecrement: {
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                    viewModel.decrement(entry.nutrient, context: modelContext)
                }
                checkForReview()
            },
            supply: supplyHint(for: entry.nutrient),
            onRefill: { nutrientToRefill = entry.nutrient },
            isLastDay: NutrientCourse.isLastDay(entry.nutrient.endDate, on: .now),
            weekly: entry.weekly,
            // In the list the swipe action covers it; the grid has none.
            onEdit: inGrid ? { edit(entry.nutrient) } : nil
        )
        .onScrollVisibilityChange(threshold: 0.6) { visible in
            cardVisibility(entry.nutrient.persistentModelID, visible: visible)
        }
        .contextMenu {
            Button {
                nutrientToLog = entry.nutrient
            } label: {
                Label("Add Exact Amount", systemImage: "number")
            }

            Button {
                edit(entry.nutrient)
            } label: {
                Label("Edit Nutrient", systemImage: "pencil")
            }

            Button {
                nutrientToMove = entry.nutrient
            } label: {
                Label("Move to Group", systemImage: "folder")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to track yet", systemImage: "leaf")
        } description: {
            Text("Add the first thing you take and it shows up here.")
        } actions: {
            Button("Add a nutrient") {
                addDraft.reset()
                selectedGroupForAdd = allGroups.first(where: \.isSystem)
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.controlPrimary)
            .foregroundStyle(Theme.controlOnPrimary)
        }
        .padding(.top, 60)
    }

    private func addNutrient() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isRemoved }))) ?? 0
        addDraft.insertNutrient(into: modelContext, group: selectedGroupForAdd ?? allGroups.first(where: \.isSystem),
                                sortOrder: count)
        viewModel.refresh(context: modelContext)
    }

    private func refreshNotificationPermission() {
        Task {
            notificationsAllowed = await NotificationService.permissionStatus() == .granted
        }
    }

    private func refreshBannerVisibility() {
        Task {
            let status = await NotificationService.permissionStatus()

            // After reinstall, iOS permission resets but CloudKit may sync stale flags.
            // If iOS hasn't been asked yet, reset the synced preferences so the banner
            // reappears and the toggle reflects reality.
            if status == .notDetermined,
               preferences.hasSeenNotificationBanner || preferences.dailyReminderEnabled {
                preferences.hasSeenNotificationBanner = false
                preferences.dailyReminderEnabled = false
            }

            let shows = NotificationService.showsPermissionBanner(status: status,
                                                                   hasSeenBanner: preferences.hasSeenNotificationBanner)
            if shows != showBanner {
                withAnimation(.unlessReduceMotion(reduceMotion)) { showBanner = shows }
            }
        }
    }

    private func enableReminder() {
        Task {
            let status = await NotificationService.permissionStatus()

            switch status {
            case .notDetermined:
                let granted = await NotificationService.requestPermission()
                if granted {
                    preferences.dailyReminderEnabled = true
                    NotificationService.refreshDailyReminder(context: modelContext)
                }

            case .granted:
                preferences.dailyReminderEnabled = true
                NotificationService.refreshDailyReminder(context: modelContext)

            case .denied:
                break
            }

            preferences.hasSeenNotificationBanner = true
            withAnimation(.unlessReduceMotion(reduceMotion)) { showBanner = false }
        }
    }

    private func dismissBanner() {
        preferences.hasSeenNotificationBanner = true
        withAnimation(.unlessReduceMotion(reduceMotion)) { showBanner = false }
    }

    private func refreshSyncBannerVisibility() {
        // Don't show sync banner if notification banner is visible, or while this device doesn't sync (switched off, or
        // no iCloud account: the CloudKit store still opens then)
        guard !showBanner, ICloudSync.isActive, FileManager.default.ubiquityIdentityToken != nil else {
            showSyncBanner = false
            return
        }

        if wasSyncRestored && !preferences.hasSeenSyncRestoredBanner {
            syncBannerVariant = .restored
            showSyncBanner = true
        } else if !wasSyncRestored && !preferences.hasSeenSyncEnabledBanner {
            syncBannerVariant = .enabled
            showSyncBanner = true
        } else {
            showSyncBanner = false
        }
    }

    private func dismissSyncBanner() {
        if syncBannerVariant == .restored {
            preferences.hasSeenSyncRestoredBanner = true
        } else {
            preferences.hasSeenSyncEnabledBanner = true
        }
        withAnimation(.unlessReduceMotion(reduceMotion)) { showSyncBanner = false }
    }

    private func refreshStreak() {
        streak = StreakService.compute(context: modelContext)
    }

    private func checkForReview() {
        ReviewService.checkAfterLogging(context: modelContext)
    }

    private func applyEdit(to nutrient: Nutrient) {
        editDraft.apply(to: nutrient)
        viewModel.refresh(context: modelContext)
    }
}

private struct TodayPreview: View {
    var body: some View {
        NavigationStack {
            TodayView()
                .navigationTitle("Today")
                .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .navigationBarTitleDisplayMode(.large)
                .withProfileMenu()
        }
        .modelContainer(previewContainer)
    }
}

#Preview("Light") {
    TodayPreview()
}

#Preview("Dark") {
    TodayPreview()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    TodayPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}
