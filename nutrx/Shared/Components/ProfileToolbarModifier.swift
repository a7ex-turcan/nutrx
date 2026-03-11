import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    @State private var showEditProfile = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuButton(showEditProfile: $showEditProfile)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    ProfileView()
                }
            }
    }
}

extension View {
    func withProfileMenu() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
