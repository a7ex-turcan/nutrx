import WidgetKit
import SwiftUI

struct NutrxCircularWidget: Widget {
    let kind = "NutrxCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            CircularWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("nutrx")
        .description("Nutrient completion ring.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct CircularWidgetView: View {
    let entry: NutrxWidgetEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.completedCount) / Double(entry.totalCount)
    }

    var body: some View {
        Gauge(value: progress) {
            Text("\(entry.completedCount)")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetURL(URL(string: "nutrx://today"))
    }
}
