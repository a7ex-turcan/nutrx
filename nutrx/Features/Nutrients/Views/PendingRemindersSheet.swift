import SwiftUI

/// Reminder times for a nutrient that hasn't been saved yet — they live on the draft and are created
/// with the nutrient. (Saved nutrients use `NutrientRemindersSheet`.)
struct PendingRemindersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var draft: NutrientDraft

    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var showDeniedAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.pendingReminderTimes, id: \.timeIntervalSinceReferenceDate) { time in
                        Label {
                            Text(time, format: .dateTime.hour().minute())
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .onDelete { offsets in
                        draft.pendingReminderTimes.remove(atOffsets: offsets)
                    }
                } footer: {
                    if draft.pendingReminderTimes.isEmpty {
                        Text("No reminders yet.")
                    }
                }

                Section {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    Button("Add Reminder") { addReminder() }
                        .disabled(isAlreadyAdded)
                } footer: {
                    if isAlreadyAdded {
                        Text("\(selectedTime, format: .dateTime.hour().minute()) is already in the list.")
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To set reminders, please enable notifications for nutrx in your device settings.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isAlreadyAdded: Bool {
        draft.hasPendingReminder(at: selectedTime)
    }

    private func addReminder() {
        Task {
            switch await NotificationService.permissionStatus() {
            case .notDetermined:
                guard await NotificationService.requestPermission() else { return }
            case .granted:
                break
            case .denied:
                showDeniedAlert = true
                return
            }

            draft.addPendingReminder(selectedTime)
        }
    }
}

#Preview("Duplicate time") {
    let draft = NutrientDraft()
    draft.addPendingReminder(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!)
    draft.addPendingReminder(Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!)
    return PendingRemindersSheet(draft: draft)
}
