import SwiftUI

/// Settings' nutrx Pro card (docs/pro/design/2-paywall: settings, settings-pro): a forest card with the ring tile.
/// Free: what Pro adds so far (`ProText.tagline`, shipped features only) and Learn more, which opens the
/// paywall. Pro: a check badge and
/// "Yearly · renews 14 Oct 2027", which opens the Pro screen.
struct ProSettingsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entitlement: ProAccess.Entitlement?
    let onLearnMore: () -> Void
    /// Opens the Pro screen. A button rather than a NavigationLink: in a List, a link adds its own chevron.
    var onOpenStatus: () -> Void = {}

    var body: some View {
        if let entitlement {
            Button(action: onOpenStatus) {
                content(subtitle: ProText.shortStatus(entitlement), trailing: nil, isPro: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows your plan and what's included")
        } else {
            Button(action: onLearnMore) {
                content(subtitle: ProText.tagline(ProFeature.listed), trailing: "Learn more", isPro: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows what nutrx Pro adds")
        }
    }

    private func content(subtitle: String, trailing: String?, isPro: Bool) -> some View {
        let title = HStack(spacing: 8) {
            Text("nutrx Pro")
                .font(.headline)
                .foregroundStyle(Theme.onForestPrimary)
            if isPro {
                TickDisc(diameter: 20)
            }
        }
        let text = VStack(alignment: .leading, spacing: 2) {
            title
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.onForestSecondary)
        }
        let chevron = Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.green)
            .accessibilityHidden(true)
        return Group {
            // At accessibility sizes the text gets the card's full width under the tile.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ProRingTile()
                        Spacer(minLength: 8)
                        chevron
                    }
                    text
                    if let trailing {
                        Text(trailing)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.green)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    ProRingTile()
                    text
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.green)
                            .fixedSize()
                    }
                    chevron
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) {
            ProRingMotif(lineWidth: 22, showsArc: false)
                .frame(width: 150, height: 150)
                .offset(x: 70)
        }
        .background(Theme.forest)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPro ? "nutrx Pro, \(subtitle)" : "nutrx Pro: \(subtitle)")
    }
}

#Preview("Free and Pro") {
    NavigationStack {
        VStack(spacing: 16) {
            ProSettingsCard(entitlement: nil) {}
            ProSettingsCard(entitlement: .init(plan: .yearly, expirationDate: .now.addingTimeInterval(86_400 * 365),
                                               isFamilyShared: false, willAutoRenew: true)) {}
        }
        .padding()
        .background(Theme.surfaceGround)
    }
    .environment(ProAccess())
}
