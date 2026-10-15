import SwiftUI

/// "Scan a label" at the top of a new nutrient's form (nutrx Pro, docs/pro/design/4-scan-label: entry): the card,
/// a note when this device reads labels without Apple Intelligence, and an "or fill in by hand" divider. Free users
/// see the PRO chip and get the paywall.
struct ScanLabelEntry: View {
    let onScan: () -> Void

    private let reading = ScanText.Reading.current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProGatedButton(action: onScan) { showsBadge in
                card(showsBadge: showsBadge)
            }
            .buttonStyle(.plain)

            if let note = ScanText.entryNote(reading, device: UIDevice.current.model) {
                if reading == .modelTurnedOff {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Spacing.cardPadding)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceChip,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                } else {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }

            divider
        }
    }

    private func card(showsBadge: Bool) -> some View {
        HStack(spacing: 12) {
            NutrientIconTile(tint: .teal, symbolName: "text.viewfinder", size: 44)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text("Scan a label")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if showsBadge { ProBadge() }
                }
                Text("Fill this in from the bottle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.lineHairline).frame(height: 1)
            Text("or fill in by hand")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .layoutPriority(1)
            Rectangle().fill(Theme.lineHairline).frame(height: 1)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .accessibilityHidden(true)
    }
}

/// The review state's banner (docs/pro/design/4-scan-label: review): what was filled and what still needs the user,
/// with Scan again.
struct ScanReviewBanner: View {
    let unread: Int
    let onScanAgain: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Label {
                Text(LabelPrefill.bannerText(unread: unread))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(NutrientTint.teal.tileGlyph)
            }
            Button("Scan again", action: onScanAgain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                .frame(minHeight: Theme.minTouchTarget)
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NutrientTint.teal.tileBackground,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control + 2, style: .continuous))
    }
}

#Preview("Entry") {
    VStack(spacing: 20) {
        ScanLabelEntry {}
        ScanReviewBanner(unread: 1) {}
    }
    .padding()
    .background(Theme.surfaceGround)
    .environment(ProAccess())
}
