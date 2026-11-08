import SwiftUI

/// A Watch list row (DESIGN.md §5.11): 30pt ring in the nutrient's tint, name, "2,000 / 4,000 IU", + button.
/// The caller puts it on a `Watch/Cell` row background. Text uses the system `.primary` (white): watchOS only
/// reads an asset colour's "Any" appearance, so `Text/Primary` would come out in its light-mode ink.
struct WatchNutrientRowView: View {
    let item: WatchNutrientItem
    let onIncrement: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The value's one line at full size, and the width it has: the goal goes on its own line when even shrunk to
    /// `valueMinimumScale` the line wouldn't fit (#378).
    @State private var valueLineWidth: CGFloat = 0
    @State private var valueSpace: CGFloat = .infinity
    private let valueMinimumScale: CGFloat = 0.7

    var body: some View {
        let nutrient = item.nutrient
        let progress = item.progress

        HStack(spacing: 8) {
            ProgressRing(nutrient: nutrient, progress: progress, lineWidth: 4.5, showsSymbol: false,
                         badgeBorderColor: Theme.watchCell)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)  // the name and value element below reads it

            VStack(alignment: .leading, spacing: 1) {
                // The largest style at which the name's widest word fits beside the ring and the +: watchOS breaks
                // a word too wide for the line ("Vita- / min D" on a 40 mm Watch, #378). A word too wide even in
                // the last style shrinks instead.
                ViewThatFits(in: .horizontal) {
                    nameText(nutrient.name, font: .headline)
                    nameText(nutrient.name, font: .subheadline.weight(.semibold))
                    nameText(nutrient.name, font: .footnote.weight(.semibold))
                }

                // Never broken mid-value: a range's goal gets its own line ("2,500" / "/ 2,300–3,500 mg"), since
                // wrapping split it after the en dash and one line had no room for it; other goals stay on one
                // line, shrinking slightly if needed ("2,000 / 4,000 IU"), else get their own line too: on a 40 mm
                // Watch the one line was cut to "2,000 / 4,0…" (#378). From xxLarge text up every goal gets its own
                // line, and at accessibility sizes that line may wrap rather than lose its unit.
                Group {
                    if nutrient.goalType == .range || dynamicTypeSize >= .xxLarge
                        || valueLineWidth * valueMinimumScale > valueSpace {
                        valueLines(progress)
                    } else {
                        valueLine(progress)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { valueSpace = $0 }
                // The one line at its natural width, measured whichever form shows (`ViewThatFits` would compare it
                // unshrunk, and split "2,000 / 4,000 IU" on a 46 mm Watch too).
                .background(alignment: .leading) {
                    valueLine(progress)
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { valueLineWidth = $0 }
                }
                .font(.footnote.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(Theme.onForestSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(valueMinimumScale)
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

    /// "2,000 / 4,000 IU", the total in the primary colour.
    private func valueLine(_ progress: GoalProgress) -> Text {
        Text("\(Text(progress.currentText).foregroundStyle(.primary)) \(Text(progress.goalText))")
    }

    /// The total over its goal, a line each.
    private func valueLines(_ progress: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(progress.currentText).foregroundStyle(.primary)
            Text(progress.goalText)
        }
    }

    /// The name in `font`. Its ideal width is its widest word's, which `ViewThatFits` compares with the row; laid out,
    /// it wraps between words in the width it's given, as Today's group headers do (#273).
    private func nameText(_ name: String, font: Font) -> some View {
        let words = name.split(separator: " ")
        return ZStack(alignment: .topLeading) {
            // Every word, since the most letters isn't the widest; one line each, so they add no height.
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .lineLimit(1)
                    .hidden()
            }
            Text(name)
                .foregroundStyle(.primary)
                // A line per word (up to three), so a too-wide word shrinks the name rather than breaking: broken,
                // it would need more lines than it has words.
                .lineLimit(min(max(words.count, 1), 3))
                .minimumScaleFactor(0.5)
                .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .font(font)
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
