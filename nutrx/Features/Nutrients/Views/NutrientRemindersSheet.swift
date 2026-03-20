import SwiftUI
import SwiftData

struct NutrientRemindersSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allReminders: [NutrientReminder]
    let nutrient: Nutrient

    @State private var showTimePicker = false
    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var showDeniedAlert = false
    @State private var showNotAskedAlert = false

    private var sortedReminders: [NutrientReminder] {
        allReminders
            .filter { $0.nutrient?.persistentModelID == nutrient.persistentModelID }
            .sorted { lhs, rhs in
                let (lh, lm) = lhs.timeComponents
                let (rh, rm) = rhs.timeComponents
                return lh < rh || (lh == rh && lm < rm)
            }
    }

    var body: some View {
        NavigationStack {
            List {
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
                    Section("New Reminder") {
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showTimePicker.toggle()
                        }
                    } label: {
                        Image(systemName: showTimePicker ? "xmark" : "plus")
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
        let reminder = NutrientReminder(nutrient: nutrient, timeOfDay: selectedTime)
        modelContext.insert(reminder)
        NotificationService.scheduleReminders(for: nutrient)

        withAnimation {
            showTimePicker = false
            selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        let sorted = sortedReminders
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        // Re-schedule after deletion
        NotificationService.scheduleReminders(for: nutrient)
    }
}

#Preview {
    let container = previewContainer
    let nutrient = try! container.mainContext.fetch(FetchDescriptor<Nutrient>()).first!

    return NutrientRemindersSheet(nutrient: nutrient)
        .modelContainer(container)
}
