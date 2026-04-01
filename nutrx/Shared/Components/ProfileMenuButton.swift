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
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: updateCachedImage)
        .onChange(of: profiles.first?.profileImageData) { _, _ in
            updateCachedImage()
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
