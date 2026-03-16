import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    @State private var showEditProfile = false
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuButton(showEditProfile: $showEditProfile, showSettings: $showSettings)
                }
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
    }
}

extension View {
    func withProfileMenu() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
