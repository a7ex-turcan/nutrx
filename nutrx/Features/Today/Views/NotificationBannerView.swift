import SwiftUI

struct NotificationBannerView: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

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

            HStack(spacing: 12) {
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
