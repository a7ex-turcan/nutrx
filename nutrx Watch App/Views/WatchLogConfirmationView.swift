import SwiftUI

/// Shown for a moment after a + tap (DESIGN.md §5.11): large ring in the tint with the new total,
/// the nutrient's name and a "+1,000 logged" pill in the tint.
struct WatchLogConfirmationView: View {
    let confirmation: WatchLogConfirmation

    @Environment(\.self) private var environment

    var body: some View {
        let nutrient = confirmation.item.nutrient
        let progress = confirmation.item.progress
        let tint = nutrient.tint

        VStack(spacing: 8) {
            ZStack {
                ProgressRing(nutrient: nutrient, progress: progress, lineWidth: 12, showsSymbol: false,
                             badgeBorderColor: .black)

                VStack(spacing: 2) {
                    Text(progress.currentText)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(progress.goalCaption)
                        .font(.caption2)
                        .foregroundStyle(Theme.onForestSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 22)
                .accessibilityHidden(true)  // the ring reads the value
            }
            .frame(width: 112, height: 112)

            Text(nutrient.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(WidgetSummary.logged(confirmation.amount))
                .font(.footnote.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(ContrastColor.ink(on: tint.color, in: environment).color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint.color, in: Capsule())
        }
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Color.black.ignoresSafeArea() }
    }
}

#if DEBUG
#Preview {
    WatchLogConfirmationView(confirmation: WatchPreviewData.confirmation)
}
#endif
