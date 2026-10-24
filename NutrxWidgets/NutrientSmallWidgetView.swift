import AppIntents
import SwiftUI
import WidgetKit

/// The small one-nutrient widget: ring and + on top, then the name, value and status (or why there's no +).
struct NutrientSmallWidgetView: View {
    let content: NutrientWidgetContent

    var body: some View {
        switch content {
        case .free:
            message(symbol: "sun.max", title: "One nutrient, on your Home Screen", detail: nil, showsPro: true)
        case .choose:
            message(symbol: "leaf", title: "Choose a nutrient", detail: "Edit the widget to pick one.",
                    showsPro: false)
        case .nutrient(let shown):
            nutrient(shown)
        }
    }

    private func nutrient(_ shown: NutrientWidgetContent.Shown) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ring(shown)
                Spacer(minLength: 4)
                if case .due = shown.status {
                    Button(intent: LogNutrientIntent(nutrientID: shown.id.uuidString)) {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.controlOnPrimary)
                            .frame(width: 44, height: 36)
                            .background(Theme.controlPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add one step of \(shown.name)")
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(shown.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                details(shown.status)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func ring(_ shown: NutrientWidgetContent.Shown) -> some View {
        let progress: GoalProgress? = if case .due(let progress) = shown.status { progress } else { nil }
        return ProgressRing(fraction: progress?.ringFraction ?? 0,
                            color: progress?.status.ringColor(tint: shown.tint) ?? shown.tint.color,
                            trackColor: shown.tint.trackColor,
                            lineWidth: 6,
                            symbolName: shown.symbolName,
                            symbolColor: shown.tint.color.opacity(progress == nil ? 0.5 : 1),
                            showsCheck: progress?.status == .met,
                            label: shown.name,
                            valueDescription: progress?.progressText ?? "")
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func details(_ status: NutrientWidgetContent.Status) -> some View {
        switch status {
        case .due(let progress):
            // Separate texts: fonts set inside an interpolated Text don't apply in widgets.
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(progress.currentText)
                    .font(.title3.weight(.bold)).fontDesign(.rounded)
                    .foregroundStyle(Theme.textPrimary)
                Text(progress.goalText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(progress.remainingText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(progress.status.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .notToday, .courseEnded, .removed:
            ForEach(status.captions, id: \.self) { caption($0) }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func message(symbol: String, title: String, detail: String?, showsPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.green)
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                if showsPro { ProBadge() }
            }
            Spacer(minLength: 6)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
