import SwiftUI
import WidgetKit

/// The Lock Screen size of the supply & courses widget: the soonest one ("Vitamin D · 6 days") and how many more.
/// Monochrome there, so the header's symbol says bottle or course.
struct SupplyRectangularWidgetView: View {
    let summary: SupplyWidgetSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let summary {
                if let first = summary.items.first {
                    Label(first.kind == .supply ? "Running low" : "Ending soon",
                          systemImage: first.kind == .supply ? "waterbottle" : "hourglass")
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                    // A long name shortens; the days never do.
                    HStack(spacing: 0) {
                        Text(first.name)
                            .lineLimit(1)
                        Text(" · \(first.shortDetail)")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .font(.subheadline.weight(.semibold))
                    if summary.items.count > 1 {
                        Text("+\(summary.items.count - 1) more")
                            .font(.subheadline)
                    }
                } else {
                    Text(SupplyWidgetSummary.onTrackTitle)
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(summary.trackedLine)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text("nutrx Pro")
                    .font(.headline)
                    .widgetAccentable()
                Text(SupplyWidgetSummary.freeTitle)
                    .font(.subheadline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)  // it was cut to one line ("Know when a bot…")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NutrxSupplyWidget()
} timeline: {
    SupplyWidgetEntry.sample
    SupplyWidgetEntry.onTrackSample
    SupplyWidgetEntry.freeSample
}
