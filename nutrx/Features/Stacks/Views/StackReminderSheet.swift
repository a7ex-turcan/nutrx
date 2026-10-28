import SwiftUI
import SwiftData

/// A stack's reminder (#137, docs/pro/REMINDERS.md §4): off, at a set time (free), or at its usual time (nutrx Pro,
/// learned from when every due nutrient in it was logged), one a day and only while the stack isn't done.
struct StackReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Bindable var stack: LogStack

    @State private var usual = UsualTime.Result.learning(samples: 0)
    @State private var showDeniedAlert = false

    private var isOn: Bool { stack.reminderMinutes >= 0 }
    private var name: String { "your \(StackReminderText.fullName(stack.name))" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Remind me", isOn: Binding(get: { isOn }, set: setOn))
                } footer: {
                    Text("One reminder a day, only if you haven't logged the stack yet.")
                }
                if isOn {
                    ReminderTimingSection(
                        atUsualTime: Binding(get: { stack.remindsAtUsualTime }, set: setUsualTime),
                        setTitle: "At a set time",
                        explanation: stack.remindsAtUsualTime
                            ? UsualTimeText.explanation(usual, start: UsualTimeText.time(stack.reminderMinutes),
                                                        isPro: proAccess?.isPro == true, name: name)
                            : nil)
                    Section {
                        DatePicker(stack.remindsAtUsualTime ? "Starting time" : "Time", selection: time,
                                   displayedComponents: .hourAndMinute)
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if stack.remindsAtUsualTime {
                                Text(UsualTimeText.startingTimeFooter(usual, name: name, setTimes: 0))
                            }
                            if let note = StackReminderText.ownRemindersNote(names: nutrientsWithOwnReminders) {
                                Text(note)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reminder")
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
        // Full height: at half height the time picker, the point of the sheet, was cut off.
        .presentationDetents([.large])
        .onAppear { usual = NotificationService.usualTime(of: stack) }
    }

    /// The set time, or at the usual time the starting time: `reminderMinutes` either way.
    private var time: Binding<Date> {
        Binding(get: {
            let minutes = max(0, stack.reminderMinutes)
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            stack.reminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            save()
        })
    }

    /// Its nutrients that remind on their own: they still do (§4), so someone who wants one nudge can turn them off.
    private var nutrientsWithOwnReminders: [String] {
        StackLogging.activeEntries(of: stack).compactMap(\.nutrient)
            .filter { !($0.reminders ?? []).isEmpty || $0.remindsAtUsualTime }
            .map(\.name)
    }

    /// On asks for notifications first, as adding a nutrient's reminder does; it starts at 9:00.
    private func setOn(_ on: Bool) {
        guard on else {
            stack.reminderMinutes = -1
            stack.remindsAtUsualTime = false
            save()
            return
        }
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
            stack.reminderMinutes = UsualTime.defaultStartMinutes
            save()
        }
    }

    private func setUsualTime(_ on: Bool) {
        stack.remindsAtUsualTime = on
        save()
    }

    private func save() {
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
    }
}

private struct StackReminderPreview: View {
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    var atUsualTime = false

    var body: some View {
        if let stack = stacks.first {
            StackReminderSheet(stack: stack)
                .onAppear {
                    stack.reminderMinutes = atUsualTime ? 8 * 60 + 30 : -1
                    stack.remindsAtUsualTime = atUsualTime
                }
        }
    }
}

#Preview("Off") {
    StackReminderPreview()
        .modelContainer(previewContainer)
}

#Preview("At the usual time, dark") {
    StackReminderPreview(atUsualTime: true)
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
