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

#Preview("Light") {
    RecapHeroCard(ring: SegmentedDayRing(met: 19, total: 23, caption: "full days"), ringSummary: "19 of 23 full days",
                  eyebrow: "September 2026", title: "123 of 127 goals met",
                  summary: "In September you met 97% of your goals, with 19 full days. Vitamin D was your steadiest, "
                      + "23 of 23 days. Protein slipped on 4 days.")
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    RecapHeroCard(ring: SegmentedDayRing(met: 201, total: 311, caption: "full days", showsTotal: false),
                  ringSummary: "201 of 311 full days", eyebrow: "2026 so far", title: "3,960 of 5,400 goals met",
                  summary: "So far in 2026 you've logged on 311 days and met 73% of your goals.")
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
