import SwiftUI

/// The forest hero at the top of a recap (docs/pro/design/5-weekly-recap): a ring, the period, the headline and the
/// summary. The week's and the month's (#136) look the same.
struct RecapHeroCard: View {
    let ring: SegmentedDayRing
    /// The ring's number in words, shown where the ring is left out (accessibility sizes).
    let ringSummary: String
    let eyebrow: String
    let title: String
    let summary: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                // At accessibility sizes the ring gives its room to the words (docs/pro/design/5-weekly-recap AX).
                if !dynamicTypeSize.isAccessibilitySize {
                    ring.frame(width: 88, height: 88)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Theme.onForestSecondary)
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.onForestPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(ringSummary)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onForestSecondary)
                    }
                }
            }
            Text(summary)
                .font(.body)
                .foregroundStyle(Theme.onForestPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: summary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
