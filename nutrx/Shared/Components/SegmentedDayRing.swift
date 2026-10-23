import SwiftUI

/// The day score as a ring of equal segments, one per active nutrient, met ones first (DESIGN.md §4.2).
/// Above 12 nutrients the segments would get too short, so it draws one continuous ring instead.
/// The caller sets the size with `.frame`: 116pt in the day-score card, 64pt on History day.
struct SegmentedDayRing: View {
    enum Style {
        /// On the forest day-score / widget card.
        case onForest
        /// On a light `Surface/Card`.
        case onSurface
    }

    let met: Int
    let total: Int
    var style: Style = .onForest
    /// Defaults to 11/116 of the ring's size.
    var lineWidth: CGFloat? = nil
    /// "3/6 goals met" in the centre.
    var showsLabel: Bool = true
    /// The words under the score: nil for "goals met" ("goal met" for one), or the weekly recap's "full days" /
    /// "days logged".
    var caption: String? = nil
    /// "3/6", or just "3" (the recap's first week: days logged so far).
    var showsTotal: Bool = true

    static let maxSegments = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metCount: Int { min(max(met, 0), max(total, 0)) }
    private var captionText: String { caption ?? "\(GoalProgress.goals(total)) met" }

    private var unmetColor: Color {
        style == .onForest ? Theme.onForestTrack : Theme.surfaceChip
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let width = lineWidth ?? side * 11 / 116
            // Proportions from the design source: radius 50 in a 116 box, 6pt visual gap between segments.
            let inset = side * 8 / 116
            let gap = side * 6 / 116
            let circumference = Double.pi * (side - 2 * inset)

            ZStack {
                if let trims = segmentTrims(circumference: circumference, gap: gap, lineWidth: width) {
                    ForEach(trims.indices, id: \.self) { index in
                        Circle()
                            .trim(from: trims[index].from, to: trims[index].to)
                            .stroke(index < metCount ? Theme.green : unmetColor,
                                    style: StrokeStyle(lineWidth: width, lineCap: .round))
                    }
                } else {
                    Circle()
                        .stroke(unmetColor, lineWidth: width)
                    Circle()
                        .trim(from: 0, to: total > 0 ? Double(metCount) / Double(total) : 0)
                        .stroke(Theme.green, style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
            .rotationEffect(.degrees(-90))
            .padding(inset)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: metCount)
            .overlay {
                if showsLabel {
                    centreLabel(side: side, innerDiameter: side - 2 * inset - 2 * width)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(showsTotal ? "\(metCount) of \(total) \(captionText)" : "\(metCount) \(captionText)"))
    }

    /// Trim ranges (0…1, clockwise from 12 o'clock) for each segment, or nil to draw a continuous ring.
    private func segmentTrims(circumference: Double, gap: Double, lineWidth: Double) -> [(from: Double, to: Double)]? {
        guard total > 1, total <= Self.maxSegments, circumference > 0 else { return nil }
        // Round caps add half a line width at each end, so trim them off along with half the gap.
        let endPadding = (gap + lineWidth) / 2 / circumference
        let share = 1 / Double(total)
        guard share > 2 * endPadding else { return nil }
        return (0..<total).map { index in
            (from: Double(index) * share + endPadding, to: Double(index + 1) * share - endPadding)
        }
    }

    private func centreLabel(side: CGFloat, innerDiameter: CGFloat) -> some View {
        CentreLabel(met: metCount, total: total, style: style, caption: captionText, showsTotal: showsTotal,
                    side: side, innerDiameter: innerDiameter)
    }

    /// "3/6" over "goals met" in the ring's centre. Also drawn by Today's collapsing day score (#243), which moves
    /// it out of the ring into the bar.
    struct CentreLabel: View {
        let met: Int
        let total: Int
        var style: Style = .onForest
        let caption: String
        var showsTotal = true
        let side: CGFloat
        let innerDiameter: CGFloat
        /// The caption fades as the label leaves the ring.
        var captionOpacity: Double = 1
        /// Where "3/6" sits in the label, for moving it exactly onto the bar's.
        var onScoreFrame: ((CGRect) -> Void)? = nil

        private static let space = "centreLabel"

        var body: some View {
            let primary = style == .onForest ? Theme.onForestPrimary : Theme.textPrimary
            let secondary = style == .onForest ? Theme.onForestSecondary : Theme.textSecondary
            let score = Text("\(met)").foregroundStyle(primary)
            let outOf = Text(showsTotal ? "/\(total)" : "").foregroundStyle(secondary)

            let scoreText = Text("\(score)\(outOf)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { onScoreFrame?($0) }

            // Drop the caption when it won't fit inside the ring (small rings, large text);
            // VoiceOver still reads "3 of 6 goals met".
            ViewThatFits {
                VStack(spacing: side * 4 / 116) {
                    scoreText
                    Text(caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondary)
                        .opacity(captionOpacity)
                }
                scoreText
                    .minimumScaleFactor(0.25)
            }
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .frame(width: innerDiameter * 0.85, height: innerDiameter * 0.85)
            .coordinateSpace(.named(Self.space))
        }
    }
}

// MARK: - Previews

private struct SegmentedDayRingPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.cardGap) {
                // Day-score card ring, on forest
                HStack(spacing: 20) {
                    SegmentedDayRing(met: 3, total: 6)
                        .frame(width: 116, height: 116)
                    SegmentedDayRing(met: 6, total: 6)
                        .frame(width: 116, height: 116)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))

                // Edge cases: none met, one nutrient, 12 segments, >12 falls back to a continuous ring
                HStack(spacing: 12) {
                    SegmentedDayRing(met: 0, total: 4).frame(width: 76, height: 76)
                    SegmentedDayRing(met: 1, total: 1).frame(width: 76, height: 76)
                    SegmentedDayRing(met: 7, total: 12).frame(width: 76, height: 76)
                    SegmentedDayRing(met: 9, total: 15).frame(width: 76, height: 76)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))

                // History-day summary ring, on a light card
                HStack(spacing: 14) {
                    SegmentedDayRing(met: 4, total: 6, style: .onSurface, lineWidth: 64 * 14 / 116, showsLabel: false)
                        .frame(width: 64, height: 64)
                    SegmentedDayRing(met: 4, total: 6, style: .onSurface)
                        .frame(width: 116, height: 116)
                    Spacer()
                }
                .padding(Theme.Spacing.cardPadding)
                .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    SegmentedDayRingPreviewGallery()
}

#Preview("Dark") {
    SegmentedDayRingPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    SegmentedDayRingPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}
