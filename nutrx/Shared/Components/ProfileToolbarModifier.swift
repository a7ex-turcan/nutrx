import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    @State private var showEditProfile = false
    @State private var showAbout = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuButton(showEditProfile: $showEditProfile, showAbout: $showAbout)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    ProfileView()
                }
            }
            .sheet(isPresented: $showAbout) {
                NavigationStack {
                    AboutView()
                        .navigationTitle("About")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
    }
}

extension View {
    func withProfileMenu() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
