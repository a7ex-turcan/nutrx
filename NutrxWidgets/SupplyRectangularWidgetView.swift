import SwiftUI
import WidgetKit

/// The Lock Screen size of the supply & courses widget: the soonest one ("Vitamin D · 6 days") and how many more.
/// Monochrome there, so the header's symbol says bottle or course.
struct SupplyRectangularWidgetView: View {
    let content: SupplyWidgetEntry.Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch content {
            case .summary(let summary):
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
            case .free:
                message(title: "nutrx Pro", SupplyWidgetSummary.freeTitle)
            case .unavailable:
                message(title: "nutrx", SupplyWidgetSummary.unavailableTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func message(title: String, _ text: String) -> some View {
        Text(title)
            .font(.headline)
            .widgetAccentable()
        Text(text)
            .font(.subheadline)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)  // it was cut to one line ("Know when a bot…")
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NutrxSupplyWidget()
} timeline: {
    SupplyWidgetEntry.sample
    SupplyWidgetEntry.onTrackSample
    SupplyWidgetEntry.freeSample
}
