import SwiftUI

/// Reminder times for a nutrient that hasn't been saved yet — they live on the draft and are created
/// with the nutrient. (Saved nutrients use `NutrientRemindersSheet`.) Or (nutrx Pro, #137) its usual time, which a
/// new nutrient has still to learn, from a starting time.
struct PendingRemindersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Bindable var draft: NutrientDraft

    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var showDeniedAlert = false

    private var atUsualTime: Bool { draft.usualReminderMinutes >= 0 }

    var body: some View {
        NavigationStack {
            List {
                if ProAccess.isStoreVisible, UsualTime.isAvailable {
                    ReminderTimingSection(
                        atUsualTime: Binding(get: { atUsualTime }, set: setUsualTime),
                        explanation: atUsualTime
                            ? UsualTimeText.explanation(.learning(samples: 0),
                                                        start: UsualTimeText.time(draft.usualReminderMinutes),
                                                        isPro: proAccess?.isPro == true, name: nutrientName)
                            : nil)
                }
                if atUsualTime {
                    startingTimeSection
                } else {
                    setTimesSections
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

    // MARK: - Set times

    @ViewBuilder
    private var setTimesSections: some View {
        Section {
            ForEach(draft.pendingReminderTimes, id: \.timeIntervalSinceReferenceDate) { time in
                Label {
                    Text(time.formatted(date: .omitted, time: .shortened))
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
                Text("\(selectedTime.formatted(date: .omitted, time: .shortened)) is already in the list.")
            }
        }
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

    // MARK: - Usual time (nutrx Pro)

    /// A new nutrient has no history yet: one reminder a day at the starting time until it's learned.
    private var startingTimeSection: some View {
        Section {
            DatePicker("Starting time", selection: Binding(get: {
                let minutes = draft.usualReminderMinutes
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
            }, set: { time in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                draft.usualReminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }), displayedComponents: .hourAndMinute)
        } footer: {
            Text(UsualTimeText.startingTimeFooter(.learning(samples: 0), name: nutrientName,
                                                  setTimes: draft.pendingReminderTimes.count))
        }
    }

    private var nutrientName: String {
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "it" : name
    }

    /// Switching on starts from the first set time (9:00 with none); the set times stay for switching back.
    private func setUsualTime(_ on: Bool) {
        guard on != atUsualTime else { return }
        let first = draft.pendingReminderTimes.first.map {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        draft.usualReminderMinutes = on ? first ?? UsualTime.defaultStartMinutes : -1
    }
}

#Preview("Duplicate time") {
    let draft = NutrientDraft()
    draft.addPendingReminder(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!)
    draft.addPendingReminder(Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!)
    return PendingRemindersSheet(draft: draft)
}
