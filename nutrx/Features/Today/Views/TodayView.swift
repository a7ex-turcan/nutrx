import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = TodayViewModel()
    @State private var nutrientForCustomAmount: Nutrient?
    @State private var nutrientToEdit: Nutrient?
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
            if viewModel.nutrientIntakes.isEmpty {
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

                    ForEach(viewModel.nutrientIntakes, id: \.nutrient.persistentModelID) { entry in
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
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.refresh(context: modelContext)
            refreshBannerVisibility()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh(context: modelContext)
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
                buttonLabel: "Save Changes"
            ) {
                applyEdit(to: nutrient)
            }
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
                    NotificationService.scheduleDailyReminder()
                }

            case .granted:
                preferences.dailyReminderEnabled = true
                NotificationService.scheduleDailyReminder()

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
