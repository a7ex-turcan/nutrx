import SwiftUI
import SwiftData

/// Settings → Notifications: the noon check-in reminder, with the permission flow, and for nutrx Pro the recaps:
/// Sunday's week, the 1st's month and 1 January's year, one switch (on unless turned off, per device; #136).
struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Query private var allPreferences: [UserPreferences]
    @State private var showDeniedAlert = false
    @AppStorage(RecapSchedule.enabledKey) private var weeklyRecapEnabled = true
    @State private var notificationsAllowed = false

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

            if ProAccess.isStoreVisible, proAccess?.isPro == true {
                Section {
                    // On only when it can actually arrive: the setting and notification permission.
                    Toggle("Recaps", isOn: Binding(
                        get: { weeklyRecapEnabled && notificationsAllowed },
                        set: { newValue in
                            guard newValue else {
                                weeklyRecapEnabled = false
                                NotificationService.refreshAllNutrientReminders(context: modelContext)
                                return
                            }
                            Task {
                                switch await NotificationService.permissionStatus() {
                                case .granted:
                                    notificationsAllowed = true
                                case .notDetermined:
                                    notificationsAllowed = await NotificationService.requestPermission()
                                case .denied:
                                    showDeniedAlert = true
                                }
                                if notificationsAllowed {
                                    weeklyRecapEnabled = true
                                    NotificationService.refreshAllNutrientReminders(context: modelContext)
                                }
                            }
                        }
                    ))
                } footer: {
                    Text("A short summary of your week on Sunday evening, your month on the 1st and your year on "
                         + "1 January: what you hit, what slipped and which day.")
                }
                .listRowBackground(Theme.surfaceCard)
            }
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
                notificationsAllowed = granted
                if granted {
                    preferences.dailyReminderEnabled = true
                    NotificationService.refreshDailyReminder(context: modelContext)
                }

            case .granted:
                notificationsAllowed = true
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
            notificationsAllowed = status == .granted
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
