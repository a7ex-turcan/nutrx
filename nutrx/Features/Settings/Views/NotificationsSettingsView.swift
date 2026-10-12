import SwiftUI
import SwiftData

/// Settings → Notifications: the noon check-in reminder, with the permission flow.
struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]
    @State private var showDeniedAlert = false

    private var preferences: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        List {
            Section {
                Toggle("Daily check-in reminder", isOn: Binding(
                    get: { preferences.dailyReminderEnabled },
                    set: { newValue in
                        if newValue {
                            enableReminder()
                        } else {
                            disableReminder()
                        }
                    }
                ))
            } footer: {
                Text("Receive a reminder at noon if you haven't logged any intake for the day.")
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .onAppear {
            refreshPermissionState()
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
                showDeniedAlert = true
            }
        }
    }

    private func disableReminder() {
        preferences.dailyReminderEnabled = false
        NotificationService.cancelDailyReminder()
    }

    private func refreshPermissionState() {
        Task {
            let status = await NotificationService.permissionStatus()
            if (status == .denied || status == .notDetermined) && preferences.dailyReminderEnabled {
                preferences.dailyReminderEnabled = false
                NotificationService.cancelDailyReminder()
            }
            if status == .granted && preferences.dailyReminderEnabled {
                NotificationService.refreshDailyReminder(context: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
            .navigationTitle("Notifications")
    }
    .modelContainer(previewContainer)
}
