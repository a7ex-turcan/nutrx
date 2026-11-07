import SwiftUI

/// Today's header: forest card with the segmented day ring, a headline, the streak and the next reminder
/// (DESIGN.md §4.3). Replaces the old emoji streak row.
struct DayScoreCard: View {
    let score: DayScore
    /// Current streak in days; the chip is hidden when nil or 0 (pass nil when streaks are disabled).
    var streak: Int? = nil
    /// Next reminder later today, if any.
    var nextReminder: UpcomingReminder? = nil
    /// Today's collapsing day score (#243) draws the ring and the card itself, and fades this text over them.
    var showsRing = true
    var showsBackground = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Stack the ring above the text at accessibility sizes so the headline keeps its width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 20))

        let card = layout {
            Group {
                if showsRing {
                    SegmentedDayRing(met: score.met, total: score.total)
                } else {
                    Color.clear
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 12) {
                Text(score.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.onForestPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let streak, streak >= 1 {
                    streakChip(days: streak)
                }

                if let nextReminder {
                    // Its own row, not a `Label`: in Today's list a row restyles a label (an indented icon, a wider
                    // gap, the text wrapping under the icon at the largest sizes) and the collapsing copy outside the
                    // list doesn't, so the line snapped to another layout as one handed over to the other (#358).
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "bell")
                        Text("\(nextReminder.nutrientName) at \(nextReminder.time, format: .dateTime.hour().minute())")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.onForestSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Next reminder: \(nextReminder.nutrientName) at \(nextReminder.time.formatted(date: .omitted, time: .shortened))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)

        Group {
            if showsBackground {
                card.cardStyle(fill: Theme.forest, cornerRadius: Theme.Radius.hero)
            } else {
                card
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func streakChip(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.greenSoft)
            Text("\(days)-day streak")
                .monospacedDigit()
                .foregroundStyle(Theme.onForestPrimary)
                // Like the headline: with the reminder line under it at the largest sizes, the chip was the text
                // SwiftUI shortened ("10-day str…") instead of growing the card (#358).
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(.footnote, design: .rounded, weight: .semibold))
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .background(Theme.onForestPrimary.opacity(0.10), in: Capsule())
    }
}

// MARK: - Previews

private struct DayScoreCardPreviewGallery: View {
    private let reminder = UpcomingReminder(
        nutrientName: "Vitamin D",
        time: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: .now)!
    )

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.cardGap) {
                DayScoreCard(score: DayScore(met: 3, total: 6), streak: 10, nextReminder: reminder)
                DayScoreCard(score: DayScore(met: 0, total: 5), nextReminder: reminder)
                DayScoreCard(score: DayScore(met: 5, total: 6), streak: 1)
                DayScoreCard(score: DayScore(met: 6, total: 6), streak: 31)
                DayScoreCard(score: DayScore(met: 2, total: 3, overLimit: 1), streak: 1)
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    DayScoreCardPreviewGallery()
}

#Preview("Dark") {
    DayScoreCardPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    DayScoreCardPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}

// The largest size: the streak chip wrapping above the reminder line, which was cut off there (#358).
#Preview("Accessibility 5") {
    DayScoreCardPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
}
