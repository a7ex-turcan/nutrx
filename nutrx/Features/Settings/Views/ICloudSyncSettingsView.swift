import SwiftUI
import SwiftData
import CloudKit

/// Settings → iCloud Sync: status, the sync toggle and Delete iCloud Data.
struct ICloudSyncSettingsView: View {
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
        return preferences.iCloudSyncEnabled ? Theme.textGreenInk : .secondary
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
            .listRowBackground(Theme.surfaceCard)

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
                .listRowBackground(Theme.surfaceCard)

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
                .listRowBackground(Theme.surfaceCard)
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
                .listRowBackground(Theme.surfaceCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
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
        ICloudSyncSettingsView()
            .navigationTitle("iCloud Sync")
    }
    .modelContainer(previewContainer)
}
