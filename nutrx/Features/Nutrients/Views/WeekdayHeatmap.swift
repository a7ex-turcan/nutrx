import SwiftUI

/// Seven squares, one per weekday, filled by the 4-week hit rate (DESIGN.md §4.8), plus a one-line
/// insight when one weekday clearly lags. No advice beyond that.
struct WeekdayHeatmap: View {
    let pattern: WeekdayPattern
    let tint: NutrientTint

    @Environment(\.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Stacked at accessibility sizes, where side by side the title broke as "Week-day" (#66).
            let header = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            header {
                Text("Weekday pattern")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("Last 4 weeks")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if dynamicTypeSize.isAccessibilitySize {
                // Two rows, four and three, from AX1 (#289): seven to a row, a square was about 43 pt wide, and the
                // percentage stopped at about 16 pt while the letters under it reached 51. Four columns in both rows,
                // so the squares stay one size; the last row's fourth is empty. (Analytics always stacks the pattern
                // and Supply here, so nothing proposes extra height.)
                let first = Array(pattern.entries.prefix(4))
                let rest = Array(pattern.entries.dropFirst(4))
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(first) { entry in day(entry) }
                    }
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(rest) { entry in day(entry) }
                        ForEach(rest.count..<4, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(pattern.entries) { entry in
                        day(entry)
                    }
                }
                // Beside a taller Supply card on large widths (#215) the squares take the extra height, centred,
                // rather than leave it empty under the card's last line; stacked, nothing proposes more.
                .frame(maxHeight: .infinity)
            }

            if let weakest = pattern.weakestWeekday {
                Text("\(calendar.weekdaySymbols[weakest - 1])s are your weakest day.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func day(_ entry: WeekdayPattern.Entry) -> some View {
        let opacity = WeekdayPattern.fillOpacity(for: entry.hitRate)
        let ink = Self.ink(on: tint, opacity: opacity, in: environment).color
        let percent = entry.hitRate.map { $0.formatted(Self.percentStyle) } ?? "–"

        return VStack(spacing: 6) {
            if dynamicTypeSize.isAccessibilitySize {
                largeTile(entry, percent: percent, fill: tint.color.opacity(opacity), ink: ink)
            } else {
                square(percent, fill: tint.color.opacity(opacity), ink: ink)
            }
            Text(calendar.veryShortWeekdaySymbols[entry.weekday - 1])
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calendar.weekdaySymbols[entry.weekday - 1])
        .accessibilityValue(entry.hitRate == nil ? "No days yet" : "\(percent) of days on target")
    }

    private func square(_ percent: String, fill: Color, ink: Color) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            // At most 64 pt: in a wide analytics pane each square was about 182 pt (#153).
            .frame(maxWidth: 64)
            .overlay {
                // The square doesn't grow with the text, so the percentage stops growing too: at the largest
                // sizes it read "1…" (#66). VoiceOver reads the full value. One size across the row (#279): each
                // square takes the largest size, up to XXXL, at which "100%" (the widest a square reads) fits,
                // rather than shrinking its own text, which left "100%" smaller than "75%" beside it. The squares
                // are all one width, so they all pick the same size.
                // A step at a time, and a 1 pt inset: on a 6.3-inch iPhone "100%" just fits at xLarge that way,
                // rather than every square dropping back to the Large size.
                ViewThatFits(in: .horizontal) {
                    percentLabel(percent, ink: ink, upTo: .xxxLarge)
                    percentLabel(percent, ink: ink, upTo: .xxLarge)
                    percentLabel(percent, ink: ink, upTo: .xLarge)
                    percentLabel(percent, ink: ink, upTo: .large)
                    // Last resort, on a square too narrow even for that: each label shrinks on its own here, so
                    // "100%" can come out smaller than "75%" again. No iPhone width gets this far.
                    percentLabel(percent, ink: ink, upTo: .xSmall)
                        .minimumScaleFactor(0.5)
                }
                .padding(1)
            }
    }

    /// From AX1 (#289): a tile at least square, taller when its label needs it. At each size, largest first, "100%" on
    /// one line, else the number over the % sign, before a size smaller. One size and form across the row, as with
    /// the squares: every tile is as wide and measures the same "100%". At most 120 pt wide (analytics is a 640 pt
    /// column at these sizes).
    private func largeTile(_ entry: WeekdayPattern.Entry, percent: String, fill: Color, ink: Color) -> some View {
        ZStack {
            Color.clear.aspectRatio(1, contentMode: .fit)
            ViewThatFits(in: .horizontal) {
                ForEach(Self.largeSteps, id: \.self) { size in
                    percentLabel(percent, ink: ink, upTo: size)
                    stackedPercent(entry.hitRate, ink: ink, upTo: size)
                }
                stackedPercent(entry.hitRate, ink: ink, upTo: .xSmall)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 120)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous))
    }

    /// The sizes a large tile's label tries, largest first.
    private static let largeSteps: [DynamicTypeSize] = [
        .accessibility5, .accessibility4, .accessibility3, .accessibility2, .accessibility1, .xxxLarge, .xxLarge,
        .xLarge, .large,
    ]

    /// The number over the % sign, at most `size`, as wide and tall as "100" over "%" would be there, so every tile
    /// in the row picks the same size and has the same height ("–" for a weekday with no days yet).
    private func stackedPercent(_ hitRate: Double?, ink: Color, upTo size: DynamicTypeSize) -> some View {
        let parts = Self.percentParts(hitRate)
        let widest = Self.percentParts(1)
        return ZStack {
            VStack(spacing: 0) {
                Text(widest.number)
                Text(widest.symbol)
            }
            .hidden()
            VStack(spacing: 0) {
                Text(parts.number)
                if !parts.symbol.isEmpty { Text(parts.symbol) }
            }
            .foregroundStyle(ink)
        }
        .font(.system(.caption2, design: .rounded, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
        .dynamicTypeSize(...size)
    }

    /// "100" and "%" from the locale's whole percentage, or "–" and nothing.
    private static func percentParts(_ hitRate: Double?) -> (number: String, symbol: String) {
        guard let hitRate else { return ("–", "") }
        let number = Int((hitRate * 100).rounded()).formatted()
        let symbol = hitRate.formatted(percentStyle).replacingOccurrences(of: number, with: "")
            .trimmingCharacters(in: .whitespaces)
        return (number, symbol)
    }

    /// A square's percentage at most `size`, as wide as "100%" would be there, which `ViewThatFits` measures.
    private func percentLabel(_ percent: String, ink: Color, upTo size: DynamicTypeSize) -> some View {
        ZStack {
            Text(Self.widestPercent)
                .hidden()
            Text(percent)
                .foregroundStyle(ink)
        }
        .font(.system(.caption2, design: .rounded, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
        .dynamicTypeSize(...size)
    }

    /// Whole percentages, for the labels and the "100%" they're sized by.
    private static let percentStyle = FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0))
    private static var widestPercent: String { 1.0.formatted(percentStyle) }
}

extension WeekdayHeatmap {
    /// Dark ink (`Text/OnTint`) or white, whichever stands out more on a square's fill — the tint at `opacity`
    /// over the card. Every tint at every fill level gets ≥ 4.5:1 this way, light and dark
    /// (`ContrastColorTests.testHeatmapInkMeetsAAForEveryTintAndFill`).
    static func ink(on tint: NutrientTint, opacity: Double,
                    in environment: EnvironmentValues) -> (color: Color, contrast: Double) {
        let card = ContrastColor(Theme.surfaceCard, in: environment)
        let fill = ContrastColor(tint.color, in: environment).blended(opacity: opacity, over: card)
        let dark = fill.contrast(with: ContrastColor(Theme.textOnTint, in: environment))
        let light = fill.contrast(with: .white)
        return dark >= light ? (Theme.textOnTint, dark) : (.white, light)
    }
}

private struct WeekdayHeatmapPreview: View {
    var tint: NutrientTint = .amber

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let goal = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)
        // Met every day except most Sundays.
        let totals = Dictionary(uniqueKeysWithValues: (1...28).map { offset -> (Date, Double) in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let isSunday = calendar.component(.weekday, from: date) == 1
            return (date, isSunday && offset > 7 ? 0 : 1)
        })
        let pattern = WeekdayPattern(totals: totals, goal: goal,
                                     createdAt: calendar.date(byAdding: .day, value: -60, to: today)!, today: .now)
        return WeekdayHeatmap(pattern: pattern, tint: tint)
            .padding(18)
            .cardStyle()
            // Its stacked size: the squares would take the canvas's height otherwise (#215).
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxHeight: .infinity)
            .background(Theme.surfaceGround)
    }
}

#Preview("Light") { WeekdayHeatmapPreview() }
#Preview("Dark") { WeekdayHeatmapPreview().preferredColorScheme(.dark) }
#Preview("Indigo — white ink") { WeekdayHeatmapPreview(tint: .indigo) }
#Preview("Largest text") { WeekdayHeatmapPreview().dynamicTypeSize(.accessibility5) }
