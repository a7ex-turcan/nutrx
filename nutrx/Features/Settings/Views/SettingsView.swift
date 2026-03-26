import SwiftUI
import SwiftData
import CloudKit

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
                    ICloudSyncSettingsView()
                        .navigationTitle("iCloud Sync")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("iCloud Sync", systemImage: "icloud")
                }

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

private struct ICloudSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var preferences: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    private var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var statusIcon: String {
        if !hasICloudAccount {
            return "xmark.icloud"
        }
        return preferences.iCloudSyncEnabled ? "checkmark.icloud" : "icloud.slash"
    }

    private var statusText: String {
        if !hasICloudAccount {
            return "No iCloud account"
        }
        return preferences.iCloudSyncEnabled ? "Syncing" : "Disabled"
    }

    private var statusColor: Color {
        if !hasICloudAccount {
            return .secondary
        }
        return preferences.iCloudSyncEnabled ? .green : .secondary
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label {
                        Text("Status")
                    } icon: {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                    }
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            }

            if hasICloudAccount {
                Section {
                    Toggle(isOn: Binding(
                        get: { preferences.iCloudSyncEnabled },
                        set: { preferences.iCloudSyncEnabled = $0 }
                    )) {
                        Text("iCloud Sync")
                    }
                } footer: {
                    Text("Your data syncs via your private iCloud container. No one else can see it.")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Label("Delete iCloud Data", systemImage: "trash")
                            if isDeleting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Permanently removes your data from iCloud. Data on this device is not affected.")
                }
            } else {
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Sign in to iCloud in Settings", systemImage: "arrow.up.forward.app")
                    }
                } footer: {
                    Text("Sign in to an iCloud account to sync your data across devices.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert("Delete iCloud Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteICloudData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your nutrx data from iCloud. Your local data on this device will not be affected. This cannot be undone.")
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "An unknown error occurred.")
        }
    }

    private func deleteICloudData() {
        isDeleting = true
        Task {
            do {
                let container = CKContainer(identifier: ModelContainerFactory.cloudKitContainerID)
                let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
                try await container.privateCloudDatabase.deleteRecordZone(withID: zoneID)
                preferences.iCloudSyncEnabled = false
                isDeleting = false
            } catch {
                isDeleting = false
                deleteError = error.localizedDescription
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
