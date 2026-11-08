import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    /// Today's opens Settings for `-screenshotRoute settings/paywall` (#362). Only Today's: on large screens Nutrients
    /// and History load at launch too, and theirs would open a second Settings in a tab that isn't showing.
    var opensSettingsRoute = false
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @State private var showEditProfile = false
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuButton(showEditProfile: $showEditProfile, showSettings: $showSettings)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    ProfileView()
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            #if DEBUG
            // `-screenshotRoute settings/paywall` (#362): Settings first; SettingsView opens the paywall over it.
            .onChange(of: router?.screenshotRoute, initial: true) { _, route in
                if opensSettingsRoute, route == .settingsPaywall { showSettings = true }
            }
            #endif
    }
}

extension View {
    /// `opensSettingsRoute`: Today's, which opens Settings for `-screenshotRoute settings/paywall` (debug builds).
    func withProfileMenu(opensSettingsRoute: Bool = false) -> some View {
        modifier(ProfileToolbarModifier(opensSettingsRoute: opensSettingsRoute))
    }
}
