import Combine
import CoreData
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allPreferences: [UserPreferences]
    @Query private var allGroups: [NutrientGroup]
    @State private var viewModel = TodayViewModel()
    @State private var nutrientToLog: Nutrient?
    @State private var nutrientToEdit: Nutrient?
    @State private var nutrientToMove: Nutrient?
    @State private var editDraft = NutrientDraft()
    @State private var showBanner = false
    @State private var showSyncBanner = false
    @State private var syncBannerVariant: SyncBannerView.Variant = .enabled
    @State private var streak: StreakResult?
    @State private var notificationsAllowed = false
    @State private var showAddSheet = false
    @State private var addDraft = NutrientDraft()
    @State private var selectedGroupForAdd: NutrientGroup?
    @AppStorage("wasSyncRestored") private var wasSyncRestored = false

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

    var body: some View {
        Group {
            if viewModel.groupSections.isEmpty {
                emptyState
            } else {
                List {
                    // Re-evaluated every minute so a reminder drops off once its time passes.
                    TimelineView(.everyMinute) { timeline in
                        DayScoreCard(
                            score: viewModel.dayScore,
                            streak: preferences.streaksEnabled ? streak?.current : nil,
                            nextReminder: notificationsAllowed ? viewModel.nextReminder(after: timeline.date) : nil
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: Theme.Spacing.screenMargin,
                                              bottom: Theme.Spacing.cardGap / 2, trailing: Theme.Spacing.screenMargin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if showBanner {
                        NotificationBannerView(
                            onEnable: { enableReminder() },
                            onDismiss: { dismissBanner() }
                        )
                        .listRowInsets(cardRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else if showSyncBanner {
                        SyncBannerView(variant: syncBannerVariant) {
                            dismissSyncBanner()
                        }
                        .listRowInsets(cardRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.groupSections) { section in
                        if hasCustomGroups {
                            groupHeader(section)
                        }
                        if !section.group.isCollapsed {
                            ForEach(section.intakes, id: \.nutrient.persistentModelID) { entry in
                                nutrientRow(entry)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.surfaceGround)
        .onAppear {
            viewModel.refresh(context: modelContext)
            refreshBannerVisibility()
            refreshNotificationPermission()
            refreshSyncBannerVisibility()
            refreshStreak()
        }
        .onChange(of: allGroups.count) {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh(context: modelContext)
                refreshStreak()
                refreshNotificationPermission()
                NotificationService.refreshDailyReminder(context: modelContext)
                viewModel.rescheduleReminders(context: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
            viewModel.refresh(context: modelContext)
            refreshStreak()
        }
        .sheet(item: $nutrientToLog) { nutrient in
            LogSheet(
                nutrient: nutrient,
                onLog: { amount, note in
                    withAnimation(.unlessReduceMotion(.easeInOut(duration: 0.2))) {
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
        .sheet(isPresented: $showAddSheet) {
            NutrientFormView(
                draft: addDraft,
                title: "New Nutrient",
                buttonLabel: "Add",
                selectedGroup: $selectedGroupForAdd,
                showGroupPicker: true
            ) {
                addNutrient()
            }
        }
    }

    /// 16pt side margins and a 10pt gap between cards.
    private var cardRowInsets: EdgeInsets {
        EdgeInsets(top: Theme.Spacing.cardGap / 2, leading: Theme.Spacing.screenMargin,
                   bottom: Theme.Spacing.cardGap / 2, trailing: Theme.Spacing.screenMargin)
    }

    private func groupHeader(_ section: TodayViewModel.GroupSection) -> some View {
        let score = DayScore(progresses: section.intakes.map(\.progress))
        return GroupHeader(
            name: section.group.name,
            met: score.met,
            total: score.total,
            isCollapsed: section.group.isCollapsed,
            onToggle: {
                withAnimation(.unlessReduceMotion(.easeInOut(duration: 0.25))) {
                    section.group.isCollapsed.toggle()
                }
            }
        )
        .listRowInsets(EdgeInsets(top: Theme.Spacing.sectionTop - Theme.Spacing.cardGap / 2,
                                  leading: Theme.Spacing.screenMargin, bottom: 0, trailing: Theme.Spacing.screenMargin))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func nutrientRow(_ entry: TodayViewModel.NutrientIntake) -> some View {
        NutrientCard(
            nutrient: entry.nutrient,
            currentIntake: entry.total,
            onOpen: {
                nutrientToLog = entry.nutrient
            },
            onIncrement: {
                withAnimation(.unlessReduceMotion(.easeInOut(duration: 0.2))) {
                    viewModel.increment(entry.nutrient, context: modelContext)
                }
                checkForReview()
            },
            onDecrement: {
                withAnimation(.unlessReduceMotion(.easeInOut(duration: 0.2))) {
                    viewModel.decrement(entry.nutrient, context: modelContext)
                }
                checkForReview()
            }
        )
        .listRowInsets(cardRowInsets)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contextMenu {
            Button {
                nutrientToLog = entry.nutrient
            } label: {
                Label("Add Exact Amount", systemImage: "number")
            }

            Button {
                editDraft.populate(from: entry.nutrient)
                nutrientToEdit = entry.nutrient
            } label: {
                Label("Edit Nutrient", systemImage: "pencil")
            }

            Button {
                nutrientToMove = entry.nutrient
            } label: {
                Label("Move to Group", systemImage: "folder")
            }
        }
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
                editDraft.populate(from: entry.nutrient)
                nutrientToEdit = entry.nutrient
            } label: {
                Label("Edit Nutrient", systemImage: "pencil")
            }
            .tint(.orange)
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
        let count = (try? modelContext.fetchCount(FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isDeleted }))) ?? 0
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
            if status == .notDetermined {
                if preferences.hasSeenNotificationBanner || preferences.dailyReminderEnabled {
                    preferences.hasSeenNotificationBanner = false
                    preferences.dailyReminderEnabled = false
                }
                showBanner = true
                return
            }

            if preferences.hasSeenNotificationBanner {
                showBanner = false
                return
            }
            showBanner = status != .granted
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
            withAnimation(.unlessReduceMotion()) { showBanner = false }
        }
    }

    private func dismissBanner() {
        preferences.hasSeenNotificationBanner = true
        withAnimation(.unlessReduceMotion()) { showBanner = false }
    }

    private func refreshSyncBannerVisibility() {
        // Don't show sync banner if notification banner is visible
        guard !showBanner else {
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
        withAnimation(.unlessReduceMotion()) { showSyncBanner = false }
    }

    private func refreshStreak() {
        streak = StreakService.compute(context: modelContext)
    }

    private func checkForReview() {
        let currentStreak = StreakService.compute(context: modelContext).current
        let totalIntakeCount = (try? modelContext.fetchCount(FetchDescriptor<IntakeRecord>())) ?? 0
        ReviewService.maybeRequestReview(
            context: modelContext,
            currentStreak: currentStreak,
            totalIntakeCount: totalIntakeCount
        )
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
