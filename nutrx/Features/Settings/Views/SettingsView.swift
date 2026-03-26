import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]

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
                NavigationLink {
                    ManageGroupsView()
                        .navigationTitle("Manage Groups")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Manage Groups", systemImage: "folder")
                }

                NavigationLink {
                    StreaksSettingsView()
                        .navigationTitle("Streaks")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Streaks", systemImage: "flame")
                }

                NavigationLink {
                    NotificationsSettingsView()
                        .navigationTitle("Notifications")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                        .navigationTitle("About")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct StreaksSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]

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
                Toggle(isOn: Binding(
                    get: { preferences.streaksEnabled },
                    set: { preferences.streaksEnabled = $0 }
                )) {
                    Text("Track streaks")
                }
            } footer: {
                Text("Show your daily completion streak on the Today and History screens.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct NotificationsSettingsView: View {
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
        }
        .listStyle(.insetGrouped)
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
            if status == .denied && preferences.dailyReminderEnabled {
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
        SettingsView()
    }
    .modelContainer(previewContainer)
}
