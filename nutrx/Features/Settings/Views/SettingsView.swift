import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dailyReminderEnabled = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    NotificationsSettingsView(dailyReminderEnabled: $dailyReminderEnabled)
                        .navigationTitle("Notifications")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }

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

private struct NotificationsSettingsView: View {
    @Binding var dailyReminderEnabled: Bool

    var body: some View {
        List {
            Section {
                Toggle("Daily check-in reminder", isOn: $dailyReminderEnabled)
            } footer: {
                Text("Receive a reminder at noon if you haven't logged any intake for the day.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
