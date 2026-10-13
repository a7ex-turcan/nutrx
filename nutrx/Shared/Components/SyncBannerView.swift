import SwiftUI

/// One-time iCloud cards on Today ("Data restored", "iCloud sync active"): a blue iCloud tile (the Settings iCloud
/// Sync colour), the message, and a dismiss ✕. Card styling like the nutrient cards around it.
struct SyncBannerView: View {
    enum Variant {
        case restored
        case enabled
    }

    let variant: Variant
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NutrientIconTile(tint: .blue, symbolName: variant == .restored ? "icloud.and.arrow.down" : "icloud",
                             size: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-12)  // keep the visual layout; only the hit area grows
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
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

private struct SyncBannerPreviewGallery: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.cardGap) {
            SyncBannerView(variant: .enabled, onDismiss: {})
            SyncBannerView(variant: .restored, onDismiss: {})
        }
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    SyncBannerPreviewGallery()
}

#Preview("Dark") {
    SyncBannerPreviewGallery()
        .preferredColorScheme(.dark)
}
