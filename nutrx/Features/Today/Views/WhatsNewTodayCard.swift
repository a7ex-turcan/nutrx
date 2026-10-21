import SwiftUI

/// "New in 2.3" on Today after an update (#148): each new thing with its tile, title and a line (the PRO chip on Pro
/// ones, never a paywall), and a close button that hides it for that release on this device.
struct WhatsNewTodayCard: View {
    let whatsNew: WhatsNew
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(whatsNew.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -10)
                .padding(.vertical, -10)
                .accessibilityLabel("Hide what's new")
            }
            ForEach(whatsNew.items, id: \.title) { item in
                row(item)
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding + 2)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func row(_ item: WhatsNew.Item) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // The words get the room at accessibility sizes.
            if !dynamicTypeSize.isAccessibilitySize {
                NutrientIconTile(tint: item.tint, symbolName: item.symbolName, size: 34)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                // On the title's first line when it wraps.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if item.isPro {
                        ProBadge()
                    }
                }
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewTodayCard(whatsNew: WhatsNew.releases[0], onDismiss: {})
        .padding()
        .background(Theme.surfaceGround)
}
