import SwiftUI

struct SyncBannerView: View {
    enum Variant {
        case restored
        case enabled
    }

    let variant: Variant
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: variant == .restored ? "icloud.and.arrow.down" : "icloud")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var title: String {
        switch variant {
        case .restored: "Data restored"
        case .enabled: "iCloud sync active"
        }
    }

    private var message: String {
        switch variant {
        case .restored:
            "Your nutrx data has been restored from iCloud."
        case .enabled:
            "Your data syncs across all your Apple devices via iCloud. You can manage or delete your iCloud data in Settings."
        }
    }
}
