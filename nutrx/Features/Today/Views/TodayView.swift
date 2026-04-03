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
    @State private var nutrientForCustomAmount: Nutrient?
    @State private var nutrientToEdit: Nutrient?
    @State private var nutrientToMove: Nutrient?
    @State private var editDraft = NutrientDraft()
    @State private var showBanner = false
    @State private var showSyncBanner = false
    @State private var syncBannerVariant: SyncBannerView.Variant = .enabled
    @State private var streak: StreakResult?
    @State private var expandedNutrientIDs: Set<UUID> = []
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
                    if let streak, streak.current >= 1, preferences.streaksEnabled {
                        HStack {
                            Spacer()
                            Text("🔥 \(streak.current)-day streak")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    if showBanner {
                        NotificationBannerView(
                            onEnable: { enableReminder() },
                            onDismiss: { dismissBanner() }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else if showSyncBanner {
                        SyncBannerView(variant: syncBannerVariant) {
                            dismissSyncBanner()
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.groupSections) { section in
                        Section {
                            if !section.group.isCollapsed {
                                ForEach(section.intakes, id: \.nutrient.persistentModelID) { entry in
                                    nutrientRow(entry)
                                }
                            }
                        } header: {
                            if hasCustomGroups {
                                GroupHeaderView(
                                    name: section.group.name,
                                    isCollapsed: section.group.isCollapsed,
                                    intakes: section.intakes.map { (current: $0.total, target: $0.nutrient.dailyTarget) },
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            section.group.isCollapsed.toggle()
                                        }
                                    }
                                )
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(4)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.refresh(context: modelContext)
            refreshBannerVisibility()
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
                NotificationService.refreshDailyReminder(context: modelContext)
                NotificationService.refreshAllNutrientReminders(context: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
            viewModel.refresh(context: modelContext)
            refreshStreak()
        }
        .sheet(item: $nutrientForCustomAmount) { nutrient in
            CustomAmountSheet(nutrient: nutrient) { amount, note in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.addCustomAmount(amount, to: nutrient, note: note, context: modelContext)
                }
                checkForReview()
            }
        }
        .sheet(item: $nutrientToEdit) { nutrient in
            NutrientFormView(
                draft: editDraft,
                title: "Edit Nutrient",
                buttonLabel: "Save Changes",
                nutrient: nutrient
            ) {
                applyEdit(to: nutrient)
            }
        }
        .sheet(item: $nutrientToMove) { nutrient in
            MoveToGroupSheet(nutrient: nutrient)
        }
    }

    private func nutrientRow(_ entry: TodayViewModel.NutrientIntake) -> some View {
        ExpandableNutrientCard(
            nutrient: entry.nutrient,
            currentIntake: entry.total,
            isExpanded: expandedNutrientIDs.contains(entry.nutrient.id),
            onToggle: {
                if expandedNutrientIDs.contains(entry.nutrient.id) {
                    expandedNutrientIDs.remove(entry.nutrient.id)
                } else {
                    expandedNutrientIDs.insert(entry.nutrient.id)
                }
            },
            onIncrement: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.increment(entry.nutrient, context: modelContext)
                }
                checkForReview()
            },
            onDecrement: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.decrement(entry.nutrient, context: modelContext)
                }
                checkForReview()
            },
            onLogExactAmount: {
                nutrientForCustomAmount = entry.nutrient
            }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contextMenu {
            Button {
                nutrientForCustomAmount = entry.nutrient
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
                nutrientForCustomAmount = entry.nutrient
            } label: {
                Image(systemName: "number")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                editDraft.populate(from: entry.nutrient)
                nutrientToEdit = entry.nutrient
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.orange)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Nutrients", systemImage: "leaf")
        } description: {
            Text("Add nutrients in the My Nutrients tab to start tracking.")
        }
        .padding(.top, 60)
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
            withAnimation { showBanner = false }
        }
    }

    private func dismissBanner() {
        preferences.hasSeenNotificationBanner = true
        withAnimation { showBanner = false }
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
        withAnimation { showSyncBanner = false }
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
        guard let stepValue = editDraft.step.parsedDouble,
              let targetValue = editDraft.dailyTarget.parsedDouble else { return }

        nutrient.name = editDraft.name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = editDraft.unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
        nutrient.goalType = editDraft.goalType
        nutrient.upperBound = editDraft.goalType == .range ? editDraft.upperBound.parsedDouble : nil
        let notes = editDraft.notes.trimmingCharacters(in: .whitespaces)
        nutrient.notes = notes.isEmpty ? nil : notes
        viewModel.refresh(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        TodayView()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
