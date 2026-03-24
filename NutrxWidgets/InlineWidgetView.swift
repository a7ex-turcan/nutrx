import WidgetKit
import SwiftUI

struct NutrxInlineWidget: Widget {
    let kind = "NutrxInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            InlineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("nutrx")
        .description("Nutrient completion count.")
        .supportedFamilies([.accessoryInline])
    }
}

struct InlineWidgetView: View {
    let entry: NutrxWidgetEntry

    var body: some View {
        if entry.totalCount == 0 {
            Text("Open nutrx")
        } else if entry.completedCount == entry.totalCount {
            Text("All done today ✓")
        } else {
            Text("\(entry.completedCount) / \(entry.totalCount) on target")
        }
    }
}
