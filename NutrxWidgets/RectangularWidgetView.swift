import WidgetKit
import SwiftUI

struct NutrxRectangularWidget: Widget {
    let kind = "NutrxRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            RectangularWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next up")
        .description("Your next goal not met yet, with its progress.")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// The next goal that still needs more — name, "2,000 / 4,000 IU" and a bar (DESIGN.md §5.10). Monochrome on
/// the Lock Screen, so the bar's length carries the progress. With none left: "All done", or how many are over
/// a limit.
struct RectangularWidgetView: View {
    let entry: NutrxWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let nutrient = entry.nextUp {
                let progress = nutrient.progress
                Text(nutrient.name)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text("\(progress.currentText) \(progress.goalText)")
                    .font(.subheadline.weight(.semibold)).fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ProgressView(value: progress.ringFraction)
                    .progressViewStyle(.linear)
                    .widgetAccentable()
                    .accessibilityHidden(true)
            } else if entry.overLimitCount > 0 {
                // Nothing left to log toward, but not every goal is met.
                Label(WidgetSummary.overLimit(entry.overLimitCount), systemImage: "exclamationmark.circle")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .accessibilityLabel(WidgetSummary.overLimit(entry.overLimitCount))
                Text("\(WidgetSummary.score(met: entry.metCount, total: entry.totalCount)) goals met")
                    .font(.subheadline)
            } else if entry.totalCount > 0 {
                Label("All done", systemImage: "checkmark.circle")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .accessibilityLabel("All done for today")  // not "Selected" from the check symbol
                Text("\(WidgetSummary.score(met: entry.metCount, total: entry.totalCount)) goals met")
                    .font(.subheadline)
            } else {
                Text("nutrx")
                    .font(.headline)
                    .widgetAccentable()
                Text("Add a nutrient to start")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "nutrx://today"))
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NutrxRectangularWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
    NutrxWidgetEntry.overLimitSample
    NutrxWidgetEntry.empty
}
