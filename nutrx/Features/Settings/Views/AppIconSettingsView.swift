import SwiftUI
import UIKit

/// Settings → App icon (nutrx Pro, #139): the icons as Home Screen tiles, the one in use outlined. A tap sets it, and
/// iOS says so in its own alert.
struct AppIconSettingsView: View {
    @State private var current = AppIconChoice.current(alternateIconName: UIApplication.shared.alternateIconName)
    @State private var failed = false

    private static let tileSize: CGFloat = 72
    /// The Home Screen's corner, about 22% of the side.
    private static let tileRadius: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 16) {
                    ForEach(AppIconChoice.allCases) { icon in
                        Button { choose(icon) } label: { tile(icon) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon.title)
                            .accessibilityAddTraits(icon == current ? .isSelected : [])
                    }
                }
                .padding(Theme.Spacing.cardPadding)
                .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                Text("Each one keeps the nutrx mark. iOS confirms the change.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .readableColumn()
        .background(Theme.surfaceGround)
        .alert("Couldn't change the icon", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again in a moment.")
        }
    }

    private func tile(_ icon: AppIconChoice) -> some View {
        let isCurrent = icon == current
        let shape = RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
        return VStack(spacing: 8) {
            Image(icon.previewImageName)
                .resizable()
                .frame(width: Self.tileSize, height: Self.tileSize)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Theme.lineHairline) }
                // The one in use: a ring a little outside the icon, in Control/Primary.
                .padding(4)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: Self.tileRadius + 4, style: .continuous)
                            .strokeBorder(Theme.controlPrimary, lineWidth: 3)
                    }
                }
                .accessibilityHidden(true)
            Text(icon.title)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func choose(_ icon: AppIconChoice) {
        guard icon != current, UIApplication.shared.supportsAlternateIcons else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
                current = icon
            } catch {
                failed = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
            .navigationTitle("App icon")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Dark, largest text") {
    NavigationStack {
        AppIconSettingsView()
            .navigationTitle("App icon")
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
