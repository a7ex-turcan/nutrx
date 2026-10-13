import WidgetKit
import SwiftUI

struct NutrxSmallWidget: Widget {
    let kind = "NutrxSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(Theme.forest, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your day at a glance: goals met, streak and what's next.")
        .supportedFamilies([.systemSmall])
    }
}

/// Forest card: "Today" and the streak, the segmented day ring with "3/6 goals met", and the next goal
/// (DESIGN.md §5.10).
struct SmallWidgetView: View {
    let entry: NutrxWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.greenSoft)
                Spacer(minLength: 4)
                if let streak = WidgetSummary.streak(days: entry.currentStreak, enabled: entry.streaksEnabled) {
                    Label("\(entry.currentStreak)", systemImage: "flame.fill")
                        .labelStyle(StreakLabelStyle())
                        .accessibilityLabel(streak)
                }
            }

            Spacer(minLength: 6)

            if entry.totalCount == 0 {
                Text("Add a nutrient to start tracking.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.onForestSecondary)
            } else {
                HStack(spacing: 10) {
                    SegmentedDayRing(met: entry.metCount, total: entry.totalCount, showsLabel: false)
                        .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 0) {
                        // Separate texts: fonts set inside an interpolated Text don't apply in widgets.
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(entry.metCount)")
                                .font(.title.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Theme.onForestPrimary)
                            Text("/\(entry.totalCount)")
                                .font(.title3.weight(.bold)).fontDesign(.rounded)
                                .foregroundStyle(Theme.onForestSecondary)
                        }
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        Text("goals met")
                            .font(.caption)
                            .foregroundStyle(Theme.onForestSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.metCount) of \(entry.totalCount) goals met")
            }

            Spacer(minLength: 6)

            Text(WidgetSummary.nextLine(firstUnmetName: entry.nextUp?.name, overLimitCount: entry.overLimitCount,
                                        total: entry.totalCount))
                .font(.caption)
                .foregroundStyle(Theme.onForestSecondary)
                .lineLimit(1)
        }
        .widgetURL(URL(string: entry.totalCount == 0 ? "nutrx://nutrients" : "nutrx://today"))
    }
}

private struct StreakLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .foregroundStyle(Theme.greenSoft)
                .font(.caption2)
            configuration.title
                .font(.subheadline.weight(.semibold)).fontDesign(.rounded)
                .foregroundStyle(Theme.onForestPrimary)
                .monospacedDigit()
        }
    }
}

#Preview("Small", as: .systemSmall) {
    NutrxSmallWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
    NutrxWidgetEntry.overLimitSample
    NutrxWidgetEntry.empty
}
