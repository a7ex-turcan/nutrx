import SwiftUI
import SwiftData

/// Settings sheet (DESIGN.md §5.9): profile card, then rows with Settings-style icon tiles — iCloud Sync,
/// Notifications, Streaks, Groups; Apple Health (Pro); Rate nutrx, About — and the privacy footer.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allPreferences: [UserPreferences]
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<NutrientGroup> { !$0.isSystem }) private var userGroups: [NutrientGroup]
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @State private var showPaywall = false
    /// Read here so the Apple Health row follows the switch on its page.
    @AppStorage(ICloudSync.enabledKey) private var iCloudSyncEnabled = true
    @AppStorage(HealthReader.connectedKey) private var healthConnected = false
    @State private var notificationsAllowed = false
    @AppStorage(RecapSchedule.enabledKey) private var weeklyRecapEnabled = true
    @State private var showProStatus = false

    @State private var showProfile = false
    /// Decoded once per photo change, not on every body pass.
    @State private var profileImage: UIImage?

    private var preferences: UserPreferences? { allPreferences.first }
    private var profile: UserProfile? { profiles.first }
    private var hasICloudAccount: Bool { FileManager.default.ubiquityIdentityToken != nil }

    var body: some View {
        List {
            Section {
                profileCard
            }
            .listRowBackground(Theme.surfaceCard)

            // docs/pro/design/2-paywall: settings / settings-pro. Hidden until Pro ships (phase 4).
            if ProAccess.isStoreVisible, let proAccess, proAccess.hasCheckedEntitlements {
                Section {
                    ProSettingsCard(entitlement: proAccess.entitlement, onLearnMore: { showPaywall = true },
                                    onOpenStatus: { showProStatus = true })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .listSectionSpacing(12)
            }

            Section {
                NavigationLink {
                    ICloudSyncSettingsView()
                        .navigationTitle("iCloud Sync")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("iCloud Sync", symbol: "icloud", color: Theme.SettingsTile.blue,
                        value: SettingsSummary.iCloud(hasAccount: hasICloudAccount,
                                                      syncEnabled: iCloudSyncEnabled))
                }
                NavigationLink {
                    NotificationsSettingsView()
                        .navigationTitle("Notifications")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Notifications", symbol: "bell", color: Theme.SettingsTile.coral,
                        value: SettingsSummary.notifications(
                            dailyReminderEnabled: preferences?.dailyReminderEnabled ?? false,
                            weeklyRecap: ProAccess.isStoreVisible && proAccess?.isPro == true && weeklyRecapEnabled
                                && notificationsAllowed))
                }
                .task { notificationsAllowed = await NotificationService.permissionStatus() == .granted }
                NavigationLink {
                    StreaksSettingsView()
                        .navigationTitle("Streaks")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Streaks", symbol: "flame", color: Theme.SettingsTile.green,
                        value: SettingsSummary.streaks(enabled: preferences?.streaksEnabled ?? true))
                }
                NavigationLink {
                    ManageGroupsView()
                        .navigationTitle("Groups")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("Groups", symbol: "folder", color: Theme.SettingsTile.indigo,
                        value: SettingsSummary.groups(userGroupCount: userGroups.count))
                }
            }
            .listRowBackground(Theme.surfaceCard)

            // Apple Health (Pro). Export data and the doctor report live in History's "Your data" (#103).
            if ProAccess.isStoreVisible, HealthReader.isAvailable {
                Section {
                    if proAccess?.isPro == true {
                        NavigationLink {
                            AppleHealthSettingsView()
                        } label: {
                            row("Apple Health", symbol: "heart.fill", color: Theme.SettingsTile.coral,
                                value: healthConnected ? "On" : "Off")
                        }
                    } else {
                        ProGatedButton(action: {}) { _ in
                            HStack(spacing: 8) {
                                row("Apple Health", symbol: "heart.fill", color: Theme.SettingsTile.coral, value: nil)
                                ProBadge()
                            }
                        }
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
                .listRowBackground(Theme.surfaceCard)
            }

            Section {
                Button {
                    // The App Store's review page, not the system prompt: iOS shows that at most three times a
                    // year (never in TestFlight), so a tap here often did nothing.
                    openURL(ReviewService.writeReviewURL)
                    // The user chose to rate, so ReviewService won't also prompt them for this version.
                    ReviewService.recordPrompt(context: modelContext)
                } label: {
                    HStack {
                        row("Rate nutrx", symbol: "star", color: Theme.SettingsTile.amber, value: nil)
                        // Leaves the app, so an outbound arrow rather than a navigation chevron.
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)  // the hint says where it goes
                    }
                    .contentShape(Rectangle())  // the whole row, not just the icon and title
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the App Store to write a review")
                NavigationLink {
                    AboutView()
                        .navigationTitle("About")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    row("About", symbol: "info.circle", color: Theme.SettingsTile.grey, value: nil)
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
        .proPaywall(isPresented: $showPaywall)
        .navigationDestination(isPresented: $showProStatus) {
            ProStatusView()
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .onChange(of: profile?.profileImageData, initial: true) { _, data in
            profileImage = data.flatMap(UIImage.init(data:))
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

    // MARK: - Rows

    /// A coloured 32pt icon tile, the title, and the current value in secondary text.
    private func row(_ title: String, symbol: String, color: Color, value: String?) -> some View {
        HStack(spacing: 14) {
            // Fixed glyph size: the tile doesn't grow with Dynamic Type (like iOS Settings), so neither does the symbol.
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: Theme.Radius.settingsTile, style: .continuous))
                .accessibilityHidden(true)
            // Value beside the title; under it at accessibility sizes, where both wouldn't fit on one line.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if let value {
                    Text(value)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(maxWidth: 260)  // a short centred block, as in the design
        }
        .font(.footnote)
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
    .environment(ProAccess())
}

#Preview("Dark") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
