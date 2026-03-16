import SwiftUI

struct ProfileMenuButton: View {
    @Binding var showEditProfile: Bool
    @Binding var showAbout: Bool

    var body: some View {
        Menu {
            Button {
                showEditProfile = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }

            Button {
                showAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }

            Button(role: .destructive) {
                // TODO: Implement log out
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
