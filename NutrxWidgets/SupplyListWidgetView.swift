import SwiftUI
import WidgetKit

/// The Home Screen sizes of the supply & courses widget: the soonest two (small) or four (medium, each a link to its
/// analytics, two by two when there are more than two), "on track" with nothing listed, the free card without Pro,
/// and "Open nutrx" when the store couldn't be read.
struct SupplyListWidgetView: View {
    let content: SupplyWidgetEntry.Content
    let isMedium: Bool

    var body: some View {
        Group {
            switch content {
            case .free:
                message(SupplyWidgetSummary.freeTitle, showsPro: true)
            case .unavailable:
                message(SupplyWidgetSummary.unavailableTitle, showsPro: false)
            case .summary(let summary):
                if summary.items.isEmpty { onTrack(summary) } else { list(summary) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var title: some View {
        Text("Supply and courses")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
    }

    private func list(_ summary: SupplyWidgetSummary) -> some View {
        let items = summary.items
        let shown = Array(items.prefix(isMedium ? 4 : 2))
        return VStack(alignment: .leading, spacing: isMedium && shown.count <= 2 ? 12 : 10) {
            if isMedium {
                // "4 bottles, 1 course" on the right: what's tracked, beside what needs a look.
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    Text(summary.trackedLine)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            } else {
                title
            }
            if isMedium && shown.count > 2 {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    ForEach(Array(stride(from: 0, to: shown.count, by: 2)), id: \.self) { index in
                        GridRow {
                            ForEach(shown[index ..< min(index + 2, shown.count)]) { item in
                                Link(destination: AppLink.nutrient(item.nutrientID).url) { row(item) }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            } else if isMedium {
                // Two or fewer: list rows across the widget, so they fill it rather than its left half (#301).
                ForEach(shown) { item in
                    Link(destination: AppLink.nutrient(item.nutrientID).url) { wideRow(item) }
                }
            } else {
                ForEach(shown) { row($0) }
            }
            Spacer(minLength: 0)
            if items.count > shown.count {
                Text("+\(items.count - shown.count) more")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func row(_ item: SupplyWidgetSummary.Item) -> some View {
        HStack(spacing: 8) {
            NutrientIconTile(tint: item.tint, symbolName: item.symbolName, size: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                detail(item, font: .caption.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The medium size with one or two items: a list row across the widget, the detail at the trailing edge (#301).
    private func wideRow(_ item: SupplyWidgetSummary.Item) -> some View {
        HStack(spacing: 10) {
            NutrientIconTile(tint: item.tint, symbolName: item.symbolName, size: 38)
                .accessibilityHidden(true)
            Text(item.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            detail(item, font: .subheadline.weight(.semibold))
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ item: SupplyWidgetSummary.Item, font: Font) -> some View {
        Text(item.detail)
            .font(font)
            .foregroundStyle(item.kind == .supply ? Theme.textAmberInk : Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func onTrack(_ summary: SupplyWidgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            Spacer(minLength: 6)
            // A decorative tick is a shape, never the checkmark symbol (VoiceOver reads that as "Selected").
            CheckmarkShape()
                .stroke(Theme.textOnTint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 10)
                .frame(width: 26, height: 26)
                .background(Theme.green, in: Circle())
                .accessibilityHidden(true)
            Text(SupplyWidgetSummary.onTrackTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(summary.trackedLine)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
    }

    private func message(_ text: String, showsPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "waterbottle")
                    .font(.title2)
                    .foregroundStyle(Theme.green)
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                if showsPro { ProBadge() }
            }
            Spacer(minLength: 6)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
    }
}
