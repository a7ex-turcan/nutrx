import SwiftUI

/// A Watch list row (DESIGN.md §5.11): 30pt ring in the nutrient's tint, name, "2,000 / 4,000 IU", + button.
/// The caller puts it on a `Watch/Cell` row background. Text uses the system `.primary` (white): watchOS only
/// reads an asset colour's "Any" appearance, so `Text/Primary` would come out in its light-mode ink.
struct WatchNutrientRowView: View {
    let item: WatchNutrientItem
    let onIncrement: () -> Void

    var body: some View {
        let nutrient = item.nutrient
        let progress = item.progress

        HStack(spacing: 8) {
            ProgressRing(nutrient: nutrient, progress: progress, lineWidth: 4.5, showsSymbol: false,
                         badgeBorderColor: Theme.watchCell)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)  // the name and value element below reads it

            VStack(alignment: .leading, spacing: 1) {
                Text(nutrient.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(Text(progress.currentText).foregroundStyle(.primary)) \(Text(progress.goalText))")
                    .font(.footnote.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(Theme.onForestSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nutrient.name)
            .accessibilityValue("\(progress.progressText), \(progress.remainingText)")

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textOnTint)
                    .frame(width: 34, height: 34)
                    .background(Theme.green, in: Circle())
                    // 44pt hit area around the 34pt disc.
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add one step of \(nutrient.name)")
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(WatchPreviewData.items) { item in
            WatchNutrientRowView(item: item, onIncrement: {})
                .listRowBackground(RoundedRectangle(cornerRadius: Theme.Radius.watchCell).fill(Theme.watchCell))
        }
    }
}
#endif
