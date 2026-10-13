import SwiftUI

/// The one-time "Stay on track" card on Today: a coral bell tile (the Settings Notifications colour), the pitch,
/// and Dismiss / Enable. Card styling like the nutrient cards around it.
struct NotificationBannerView: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                NutrientIconTile(tint: .coral, symbolName: "bell.badge", size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stay on track")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Get a daily reminder at noon if you haven't logged any nutrients yet. You can change this anytime in Settings.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            // Side by side, stacked at accessibility sizes so the labels don't break mid-word.
            let buttons = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            buttons {
                Button {
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(Theme.controlPrimary)

                Button {
                    onEnable()
                } label: {
                    Text("Enable")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                // Forest with white in light, bright green with dark ink in dark (white on that green is ~2.5:1).
                .tint(Theme.controlPrimary)
                .foregroundStyle(Theme.controlOnPrimary)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
    }
}

#Preview("Light") {
    NotificationBannerView(onEnable: {}, onDismiss: {})
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    NotificationBannerView(onEnable: {}, onDismiss: {})
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
