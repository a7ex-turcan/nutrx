import SwiftUI
import SwiftData

struct ProfileMenuButton: View {
    @Binding var showEditProfile: Bool
    @Binding var showSettings: Bool
    @Query private var profiles: [UserProfile]

    @State private var cachedImage: UIImage?
    @State private var cachedDataIdentity: Int?

    var body: some View {
        Menu {
            Button {
                showEditProfile = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }

            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                // TODO: Implement log out
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            avatar
                .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                .background(Theme.avatarFill, in: Circle())
                .clipShape(Circle())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .accessibilityLabel("Profile menu")
        .onAppear(perform: updateCachedImage)
        .onChange(of: profiles.first?.profileImageData) { _, _ in
            updateCachedImage()
        }
    }

    /// Profile photo, else the name's initial, else a person symbol (DESIGN.md §3, §5.1).
    @ViewBuilder
    private var avatar: some View {
        if let cachedImage {
            Image(uiImage: cachedImage)
                .resizable()
                .scaledToFill()
        } else if let initial = profiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines).first {
            Text(String(initial).uppercased())
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.avatarInk)
        } else {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(Theme.avatarInk)
        }
    }

    private func updateCachedImage() {
        let data = profiles.first?.profileImageData
        let identity = data?.hashValue

        guard identity != cachedDataIdentity else { return }
        cachedDataIdentity = identity

        if let data, let uiImage = UIImage(data: data) {
            // Downscale to toolbar size (3x for retina)
            let size = CGSize(width: 90, height: 90)
            let renderer = UIGraphicsImageRenderer(size: size)
            cachedImage = renderer.image { _ in
                uiImage.draw(in: CGRect(origin: .zero, size: size))
            }
        } else {
            cachedImage = nil
        }
    }
}
