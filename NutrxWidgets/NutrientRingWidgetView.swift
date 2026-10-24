import SwiftUI
import WidgetKit

/// A gauge ring for the nutrient, its symbol inside, a tick once met. Monochrome on the Lock Screen.
struct NutrientRingWidgetView: View {
    let content: NutrientWidgetContent

    var body: some View {
        switch content {
        case .free:
            ZStack {
                AccessoryWidgetBackground()
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .widgetAccentable()
            }
            .accessibilityLabel("nutrx Pro")
        case .choose:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "leaf")
                    .font(.title3)
            }
            .accessibilityLabel("Choose a nutrient")
        case .nutrient(let shown):
            ring(shown)
        }
    }

    private func ring(_ shown: NutrientWidgetContent.Shown) -> some View {
        let progress: GoalProgress? = if case .due(let progress) = shown.status { progress } else { nil }
        return Gauge(value: progress?.ringFraction ?? 0) {
            EmptyView()
        } currentValueLabel: {
            if progress?.status == .met {
                CheckmarkShape()
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 16, height: 13)
            } else {
                Image(systemName: shown.symbolName)
                    .font(.title3)
                    .opacity(progress == nil ? 0.5 : 1)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shown.name)
        .accessibilityValue(accessibilityValue(shown.status))
    }

    private func accessibilityValue(_ status: NutrientWidgetContent.Status) -> String {
        guard case .due(let progress) = status else { return status.captions.joined(separator: ". ") }
        return "\(progress.progressText), \(progress.remainingText)"
    }
}
