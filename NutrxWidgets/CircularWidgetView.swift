import WidgetKit
import SwiftUI

struct NutrxCircularWidget: Widget {
    let kind = "NutrxCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            CircularWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Goals")
        .description("Goals met today, as a ring.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock Screen ring with "3/6" (DESIGN.md §5.10). Monochrome there, so the ring's fill carries the meaning.
struct CircularWidgetView: View {
    let entry: NutrxWidgetEntry

    private var fraction: Double {
        entry.totalCount > 0 ? Double(entry.metCount) / Double(entry.totalCount) : 0
    }

    var body: some View {
        Gauge(value: fraction) {
            EmptyView()
        } currentValueLabel: {
            Text(WidgetSummary.score(met: entry.metCount, total: entry.totalCount))
                .font(.body.weight(.bold)).fontDesign(.rounded)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("\(entry.metCount) of \(entry.totalCount) \(GoalProgress.goals(entry.totalCount)) met")
        .widgetURL(URL(string: "nutrx://today"))
    }
}

#Preview("Circular", as: .accessoryCircular) {
    NutrxCircularWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
}
