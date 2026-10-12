import SwiftUI
import SwiftData
import StoreKit

/// Settings sheet (DESIGN.md §5.9): profile card, then rows with Settings-style icon tiles — iCloud Sync,
/// Notifications, Streaks, Groups; Rate nutrx, About — and the privacy footer.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query private var allPreferences: [UserPreferences]
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<NutrientGroup> { !$0.isSystem }) private var userGroups: [NutrientGroup]

    @State private var showProfile = false

    private var preferences: UserPreferences? { allPreferences.first }
    private var profile: UserProfile? { profiles.first }
    private var hasICloudAccount: Bool { FileManager.default.ubiquityIdentityToken != nil }

    var body: some View {
        List {
            Section {
                profileCard
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                NavigationLink {
                    ICloudSyncSettingsView()
                        .navigationTitle("iCloud Sync")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("iCloud Sync", symbol: "icloud", color: NutrientTint.blue.color,
                        value: SettingsSummary.iCloud(hasAccount: hasICloudAccount,
                                                      syncEnabled: preferences?.iCloudSyncEnabled ?? true))
                }
                NavigationLink {
                    NotificationsSettingsView()
                        .navigationTitle("Notifications")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Notifications", symbol: "bell", color: NutrientTint.coral.color,
                        value: SettingsSummary.notifications(dailyReminderEnabled: preferences?.dailyReminderEnabled ?? false))
                }
                NavigationLink {
                    StreaksSettingsView()
                        .navigationTitle("Streaks")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Streaks", symbol: "flame", color: NutrientTint.green.color,
                        value: SettingsSummary.streaks(enabled: preferences?.streaksEnabled ?? true))
                }
                NavigationLink {
                    ManageGroupsView()
                        .navigationTitle("Groups")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Groups", symbol: "folder", color: NutrientTint.indigo.color,
                        value: SettingsSummary.groups(userGroupCount: userGroups.count))
                }
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                Button {
                    requestReview()
                } label: {
                    HStack {
                        row("Rate nutrx", symbol: "star", color: NutrientTint.amber.color, value: nil)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())  // the whole row, not just the icon and title
                }
                .buttonStyle(.plain)
                NavigationLink {
                    AboutView()
                        .navigationTitle("About")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("About", symbol: "info.circle", color: Color(.systemGray), value: nil)
                }
            } footer: {
                privacyFooter
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 16) {
                ProfileAvatar(image: profileImage, name: profile?.name ?? "", size: 56, style: .forest)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SettingsSummary.profileTitle(name: profile?.name ?? ""))
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Edit profile")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your profile")
    }

    private var profileImage: UIImage? {
        profile?.profileImageData.flatMap(UIImage.init(data:))
    }

    // MARK: - Rows

    /// A coloured 32pt icon tile, the title, and the current value in secondary text.
    private func row(_ title: String, symbol: String, color: Color, value: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: Theme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private var privacyFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.title3)
            Text("Private by design. No accounts, no servers, no tracking. Your data lives on your devices and your iCloud.")
                .multilineTextAlignment(.center)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(previewContainer)
}

#Preview("Dark") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
