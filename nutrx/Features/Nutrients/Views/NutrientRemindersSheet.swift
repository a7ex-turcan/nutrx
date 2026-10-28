import SwiftUI
import SwiftData

/// A saved nutrient's reminders: at set times, or (nutrx Pro, #137) one a day at its usual time, with a starting time
/// until it's learned (`ReminderTimingSection`).
struct NutrientRemindersSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let nutrient: Nutrient
    /// Fetched, and fetched again after each add or delete. The \@Query this replaced didn't update in this sheet
    /// (opened from Edit Nutrient), so an added time never appeared and people added it again (#163).
    @State private var reminders: [NutrientReminder] = []

    @State private var showTimePicker = false
    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var showDeniedAlert = false
    @State private var showNotAskedAlert = false
    /// At the usual time (`Nutrient.remindsAtUsualTime`), and what it has learned.
    @State private var atUsualTime = false
    @State private var usual = UsualTime.Result.learning(samples: 0)

    private var sortedReminders: [NutrientReminder] {
        reminders
            .sorted { lhs, rhs in
                let (lh, lm) = lhs.timeComponents
                let (rh, rm) = rhs.timeComponents
                return lh < rh || (lh == rh && lm < rm)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if ProAccess.isStoreVisible, UsualTime.isAvailable {
                    ReminderTimingSection(atUsualTime: Binding(get: { atUsualTime }, set: setUsualTime),
                                          explanation: atUsualTime ? usualExplanation : nil)
                }
                if atUsualTime {
                    startingTimeSection
                } else {
                    setTimesSections
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !atUsualTime {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.unlessReduceMotion(reduceMotion)) {
                                showTimePicker.toggle()
                            }
                        } label: {
                            Image(systemName: showTimePicker ? "xmark" : "plus")
                        }
                        .accessibilityLabel(showTimePicker ? "Cancel" : "Add Reminder")
                    }
                }
            }
            .alert("Enable Notifications", isPresented: $showNotAskedAlert) {
                Button("Enable") {
                    requestAndAdd()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("nutrx needs notification permissions to send you reminders. You'll be prompted to allow notifications.")
            }
            .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You've previously denied notification permissions for nutrx. To enable reminders, please turn on notifications in your device settings.")
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            loadReminders()
            atUsualTime = nutrient.remindsAtUsualTime
            usual = NotificationService.usualTime(of: nutrient)
        }
    }

    // MARK: - Usual time (nutrx Pro)

    private var usualExplanation: String {
        UsualTimeText.explanation(usual, start: UsualTimeText.time(max(0, nutrient.usualReminderMinutes)),
                                  isPro: proAccess?.isPro == true, name: nutrient.name)
    }

    /// Switching on starts from the earliest set time (9:00 with none); the set times stay for switching back.
    private func setUsualTime(_ on: Bool) {
        guard on != atUsualTime else { return }
        atUsualTime = on
        let earliest = sortedReminders.first.map { $0.timeComponents.hour * 60 + $0.timeComponents.minute }
        nutrient.usualReminderMinutes = on ? earliest ?? UsualTime.defaultStartMinutes : -1
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
    }

    /// One reminder a day at the starting time until the usual time is learned (and without Pro). It's its own
    /// value: the set times aren't touched.
    private var startingTimeSection: some View {
        Section {
            DatePicker("Starting time", selection: Binding(get: {
                let minutes = max(0, nutrient.usualReminderMinutes)
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
            }, set: { time in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                nutrient.usualReminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                try? modelContext.save()
                NotificationService.refreshAllNutrientReminders(context: modelContext)
            }), displayedComponents: .hourAndMinute)
        } footer: {
            Text(UsualTimeText.startingTimeFooter(usual, name: nutrient.name, setTimes: sortedReminders.count))
        }
    }

    // MARK: - Set times

    @ViewBuilder
    private var setTimesSections: some View {
        if sortedReminders.isEmpty {
            Section {
                Text("No reminders configured. Tap + to add one.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(sortedReminders, id: \.persistentModelID) { reminder in
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)

                        Text(reminder.formattedTime)
                            .font(.body)

                        Spacer()
                    }
                }
                .onDelete(perform: deleteReminders)
            } footer: {
                Text("Reminders fire daily at the configured times. If you've already logged \(nutrient.name) that day, upcoming reminders are silenced.")
            }
        }

        if showTimePicker {
            Section {
                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )

                Button {
                    addReminder()
                } label: {
                    Text("Add Reminder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.controlPrimary)
                .foregroundStyle(Theme.controlOnPrimary)
                .disabled(isAlreadyAdded)
            } header: {
                Text("New Reminder")
            } footer: {
                if isAlreadyAdded {
                    Text("\(selectedTime.formatted(date: .omitted, time: .shortened)) is already in the list.")
                }
            }
        }
    }

    private var isAlreadyAdded: Bool {
        NutrientReminder.hasReminder(at: selectedTime, among: reminders)
    }

    /// This nutrient's reminders. Loaded on appear and after each add or delete, so one synced in from another device
    /// while the sheet is open shows the next time it's opened.
    private func loadReminders() {
        let nutrientID = nutrient.id
        let descriptor = FetchDescriptor<NutrientReminder>(predicate: #Predicate { $0.nutrient?.id == nutrientID })
        reminders = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func addReminder() {
        Task {
            let status = await NotificationService.permissionStatus()

            switch status {
            case .notDetermined:
                showNotAskedAlert = true
                return

            case .granted:
                break

            case .denied:
                showDeniedAlert = true
                return
            }

            insertReminder()
        }
    }

    private func requestAndAdd() {
        Task {
            let granted = await NotificationService.requestPermission()
            if granted {
                insertReminder()
            }
        }
    }

    private func insertReminder() {
        guard !isAlreadyAdded else { return }
        let reminder = NutrientReminder(nutrient: nutrient, timeOfDay: selectedTime)
        modelContext.insert(reminder)
        try? modelContext.save()
        loadReminders()
        NotificationService.refreshAllNutrientReminders(context: modelContext)

        withAnimation(.unlessReduceMotion(reduceMotion)) {
            showTimePicker = false
            selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        let sorted = sortedReminders
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        // Saved first, so the reschedule no longer sees the deleted reminders.
        try? modelContext.save()
        loadReminders()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
    }
}

#Preview {
    let container = previewContainer
    let nutrient = try! container.mainContext.fetch(FetchDescriptor<Nutrient>()).first!

    return NutrientRemindersSheet(nutrient: nutrient)
        .modelContainer(container)
}
