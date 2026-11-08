import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
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
                if route == .settingsPaywall { showSettings = true }
            }
            #endif
    }
}

extension View {
    func withProfileMenu() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
