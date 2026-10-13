import SwiftUI

/// A Watch list row (DESIGN.md §5.11): 30pt ring in the nutrient's tint, name, "2,000 / 4,000 IU", + button.
/// The caller puts it on a `Watch/Cell` row background. Text uses the system `.primary` (white): watchOS only
/// reads an asset colour's "Any" appearance, so `Text/Primary` would come out in its light-mode ink.
struct WatchNutrientRowView: View {
    let item: WatchNutrientItem
    let onIncrement: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

                // Never broken mid-value: a range's goal gets its own line ("2,500" / "/ 2,300–3,500 mg"), since
                // wrapping split it after the en dash and one line had no room for it; other goals stay on one
                // line, shrinking slightly if needed ("2,000 / 4,000 IU"). From xxLarge text up every goal gets
                // its own line, and at accessibility sizes that line may wrap rather than lose its unit.
                Group {
                    if nutrient.goalType == .range || dynamicTypeSize >= .xxLarge {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(progress.currentText).foregroundStyle(.primary)
                            Text(progress.goalText)
                        }
                    } else {
                        Text("\(Text(progress.currentText).foregroundStyle(.primary)) \(Text(progress.goalText))")
                    }
                }
                .font(.footnote.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(Theme.onForestSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nutrient.name)
            .accessibilityValue("\(progress.progressText), \(progress.remainingText)")

            // `Button { } label: { }`, not `Button(action:) { }`: the latter is ambiguous in the preview's
            // design-time rewrite and kept this file's previews from compiling (#24).
            Button {
                onIncrement()
            } label: {
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
