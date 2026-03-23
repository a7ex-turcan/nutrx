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
                    if showBanner {
                        NotificationBannerView(
                            onEnable: { enableReminder() },
                            onDismiss: { dismissBanner() }
                        )
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
                .listStyle(.plain)
                .listSectionSpacing(4)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.refresh(context: modelContext)
            refreshBannerVisibility()
        }
        .onChange(of: allGroups.count) {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh(context: modelContext)
                NotificationService.refreshDailyReminder(context: modelContext)
                NotificationService.refreshAllNutrientReminders(context: modelContext)
            }
        }
        .sheet(item: $nutrientForCustomAmount) { nutrient in
            CustomAmountSheet(nutrient: nutrient) { amount, note in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.addCustomAmount(amount, to: nutrient, note: note, context: modelContext)
                }
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
        NutrientRowView(
            nutrient: entry.nutrient,
            currentIntake: entry.total,
            onIncrement: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.increment(entry.nutrient, context: modelContext)
                }
            },
            onDecrement: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.decrement(entry.nutrient, context: modelContext)
                }
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
            if preferences.hasSeenNotificationBanner {
                showBanner = false
                return
            }
            let status = await NotificationService.permissionStatus()
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

    private func applyEdit(to nutrient: Nutrient) {
        guard let stepValue = Double(editDraft.step),
              let targetValue = Double(editDraft.dailyTarget) else { return }

        nutrient.name = editDraft.name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = editDraft.unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
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
