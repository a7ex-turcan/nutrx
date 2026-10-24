import SwiftUI
import WidgetKit

/// The Home Screen sizes of the supply & courses widget: the soonest two (small) or four (medium, each a link to its
/// analytics, two by two when there are more than two), "on track" with nothing listed, and the free card without Pro.
struct SupplyListWidgetView: View {
    let summary: SupplyWidgetSummary?
    let isMedium: Bool

    var body: some View {
        Group {
            if let summary {
                if summary.items.isEmpty { onTrack(summary) } else { list(summary.items) }
            } else {
                free
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

    private func list(_ items: [SupplyWidgetSummary.Item]) -> some View {
        let shown = Array(items.prefix(isMedium ? 4 : 2))
        return VStack(alignment: .leading, spacing: 10) {
            title
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
                // Two or fewer: one column, so they don't sit side by side over an empty half.
                ForEach(shown) { item in
                    Link(destination: AppLink.nutrient(item.nutrientID).url) { row(item) }
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
                Text(item.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.kind == .supply ? Theme.textAmberInk : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
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

    private var free: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "waterbottle")
                    .font(.title2)
                    .foregroundStyle(Theme.green)
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                ProBadge()
            }
            Spacer(minLength: 6)
            Text(SupplyWidgetSummary.freeTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
    }
}
