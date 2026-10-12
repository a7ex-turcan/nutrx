import SwiftUI

struct NotificationBannerView: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "bell.badge")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stay on track")
                        .font(.subheadline.weight(.semibold))

                    Text("Get a daily reminder at noon if you haven't logged any nutrients yet. You can change this anytime in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
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
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NotificationBannerView(onEnable: {}, onDismiss: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
