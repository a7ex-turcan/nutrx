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

            draft.pendingReminderTimes.append(selectedTime)
            draft.pendingReminderTimes.sort { lhs, rhs in
                let lc = Calendar.current.dateComponents([.hour, .minute], from: lhs)
                let rc = Calendar.current.dateComponents([.hour, .minute], from: rhs)
                return (lc.hour!, lc.minute!) < (rc.hour!, rc.minute!)
            }
        }
    }
}
