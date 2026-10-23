import SwiftUI

/// Where Today's day-score card is as it scrolls, and where its collapsed form pins (#243). Kept apart from
/// `TodayView`'s state so a scroll only redraws the card and the collapsing copy, not the whole of Today.
@Observable
final class DayScoreCardTracker {
    /// The card's frame on screen.
    var cardFrame: CGRect?
    /// On screen, where the card's top stops: just under the navigation bar.
    var pinTop: CGFloat?
    /// Goes up when the collapsed bar is tapped; Today scrolls back to the card (#246).
    private(set) var scrollBackRequests = 0

    func requestScrollBack() { scrollBackRequests += 1 }

    /// The card's top has reached the pin, so the collapsing copy draws it from here on.
    var isCollapsing: Bool {
        guard let cardFrame, let pinTop else { return false }
        return cardFrame.minY < pinTop
    }
}

extension View {
    /// The day-score card reports where it is, and hides while its collapsing copy stands in for it.
    func tracksDayScoreCard(_ tracker: DayScoreCardTracker, isActive: Bool) -> some View {
        modifier(DayScoreCardTracking(tracker: tracker, isActive: isActive))
    }
}

private struct DayScoreCardTracking: ViewModifier {
    let tracker: DayScoreCardTracker
    let isActive: Bool

    func body(content: Content) -> some View {
        let hidden = isActive && tracker.isCollapsing
        content
            .opacity(hidden ? 0 : 1)
            .accessibilityHidden(hidden)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tracker.cardFrame = $0 }
    }
}

/// Over Today's list or columns: once the day-score card's top reaches the navigation bar, a copy pinned there that
/// shrinks with what's left of the card, its ring unrolling into the bar's line (#243). On the page's ground, so
/// nothing scrolling under it shows above or beside it.
struct CollapsingDayScoreOverlay: View {
    let tracker: DayScoreCardTracker
    let score: DayScore
    var streak: Int?
    var nextReminder: UpcomingReminder?

    /// The card's top margin in the list and the columns.
    static let topMargin: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            if tracker.isCollapsing, let card = tracker.cardFrame {
                let height = max(card.maxY - (origin.y + Self.topMargin), CollapsingDayScore.barHeight)
                ZStack(alignment: .topLeading) {
                    Theme.surfaceGround
                        .frame(width: geo.size.width, height: Self.topMargin + height)
                    CollapsingDayScore(score: score, streak: streak, nextReminder: nextReminder,
                                       cardHeight: card.height, visibleHeight: height)
                        .frame(width: card.width)
                        .offset(x: card.minX - origin.x, y: Self.topMargin)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Scrolls back to the day score")
                        .accessibilityAction { tracker.requestScrollBack() }
                    if height <= CollapsingDayScore.barHeight {
                        TouchBlocker(onTap: tracker.requestScrollBack)
                            .frame(width: geo.size.width, height: Self.topMargin + height)
                    }
                }
                // While it's collapsing, all that's under it is the hidden card itself, so a drag that starts on it
                // scrolls Today. Once it's the bar, other cards are under it, and it keeps the touches so a tap
                // can't press a hidden − or +.
                .allowsHitTesting(height <= CollapsingDayScore.barHeight)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY + Self.topMargin } action: {
            tracker.pinTop = $0
        }
    }
}

/// Takes the touches under the slim bar. A SwiftUI overlay alone doesn't keep them from a list row's buttons
/// underneath, which live in the row's own hosting view: a tap on the bar pressed a hidden +. A tap on it scrolls
/// Today back to the card (#246).
private struct TouchBlocker: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.tapped)))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        @objc func tapped() { onTap() }
    }
}

/// The day-score card part way to the slim bar: `visibleHeight` of its `cardHeight` showing, down to the 44 pt bar.
/// The ring unrolls into the bar's line, one segment per goal (`DayScoreMorph`); "3/6" shrinks into the bar's left
/// end; the headline and streak chip fade as the bar's streak comes in.
struct CollapsingDayScore: View {
    let score: DayScore
    var streak: Int?
    var nextReminder: UpcomingReminder?
    let cardHeight: CGFloat
    let visibleHeight: CGFloat

    static let barHeight = Theme.minTouchTarget
    /// The bar's side padding.
    private static let barInset: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var barLabelWidth: CGFloat = 0
    /// Where the ring's "3/6" sits in its label, unscaled.
    @State private var ringScoreFrame: CGRect?
    @State private var barStreakWidth: CGFloat = 0
    @State private var width: CGFloat = 0

    private var progress: Double {
        DayScoreMorph.progress(visibleHeight: visibleHeight, cardHeight: cardHeight, barHeight: Self.barHeight)
    }

    private var showsStreak: Bool { (streak ?? 0) >= 1 }

    /// The bar's line between "3/6" and the streak.
    private var line: DayScoreMorph.Line {
        let start = Self.barInset + barLabelWidth + 12
        let end = width - Self.barInset - (showsStreak ? barStreakWidth + 12 : 0)
        return DayScoreMorph.Line(start: CGPoint(x: start, y: Self.barHeight / 2), length: max(end - start, 0),
                                  lineWidth: 6, gap: 3)
    }

    private var morph: DayScoreMorph { DayScoreMorph(ring: DayScoreMorph.cardRing, line: line) }

    /// The ring's shape changes on a gentler curve than the scroll, so it starts and settles softly.
    private var shapeProgress: Double {
        reduceMotion ? 0 : progress * progress * (3 - 2 * progress)
    }

    /// Where the bar's row runs across: along the line as it settles.
    private var rowY: CGFloat {
        morph.anchor(at: shapeProgress).y
    }

    var body: some View {
        let progress = progress
        // Gone before the rolling ring reaches the headline.
        let fadeOut = DayScoreMorph.stage(progress, from: 0, to: 0.15)
        let barIn = DayScoreMorph.stage(progress, from: 0.6, to: 1)

        ZStack(alignment: .topLeading) {
            // The card's own words, fading and drifting up as it closes.
            DayScoreCard(score: score, streak: streak, nextReminder: nextReminder, showsRing: false,
                         showsBackground: false)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(1 - fadeOut)
                .offset(y: -16 * fadeOut)

            ringAndLine(progress: progress)
                .frame(width: width, height: max(cardHeight, Self.barHeight))

            // Where "3/6" sits in the ring's label, measured on a still copy: measuring the moving one fed its own
            // position back into itself (pixel rounding shifts it a fraction at every spot) and never settled.
            ringLabelLayout(onScoreFrame: { ringScoreFrame = $0 })
                .hidden()
                .position(DayScoreMorph.cardRing.center)

            ringLabel(progress: progress)

            // Takes over from the moving one once that has all but landed on it.
            barLabel
                .opacity(DayScoreMorph.stage(progress, from: reduceMotion ? 0.5 : 0.92, to: 1))
                .position(x: Self.barInset + barLabelWidth / 2, y: rowY)

            if showsStreak {
                barStreak
                    .opacity(barIn)
                    .position(x: width - Self.barInset - barStreakWidth / 2, y: rowY)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(visibleHeight, Self.barHeight), alignment: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius(progress), style: .continuous))
        .cardStyle(fill: Theme.forest, cornerRadius: cornerRadius(progress))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        // What shows, not the card's full height that the fading words still take up behind the clip.
        .contentShape(.accessibility, RoundedRectangle(cornerRadius: cornerRadius(progress), style: .continuous))
    }

    private func cornerRadius(_ progress: Double) -> CGFloat {
        Theme.Radius.hero + (Self.barHeight / 2 - Theme.Radius.hero) * CGFloat(progress)
    }

    // MARK: - Ring to line

    private func ringAndLine(progress: Double) -> some View {
        let morph = morph
        let segmented = DayScoreMorph.isSegmented(total: score.total)
        let pieces = DayScoreMorph.pieces(met: score.met, total: score.total)
        let shape = shapeProgress
        let reduceMotion = reduceMotion
        return Canvas { context, _ in
            // With Reduce Motion the ring fades into the line in place instead of unrolling.
            let stages: [(progress: Double, opacity: Double)] = reduceMotion
                ? [(0, 1 - progress), (1, progress)]
                : [(shape, 1)]
            for stage in stages where stage.opacity > 0 {
                context.opacity = stage.opacity
                let width = morph.lineWidth(at: stage.progress)
                for piece in pieces {
                    guard let stroke = morph.stroke(piece, segmented: segmented, at: stage.progress) else { continue }
                    var path = Path()
                    path.addLines(morph.points(from: stroke.from, to: stroke.to, progress: stage.progress))
                    context.stroke(path, with: .color(piece.isMet ? Theme.green : Theme.onForestTrack),
                                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Labels

    /// The ring's "3/6": rises and shrinks onto the bar's, at its size, fading as the bar's comes in.
    private func ringLabel(progress: Double) -> some View {
        let ring = DayScoreMorph.cardRing
        // It waits until the ring has rolled out of its way, and has landed by the time the bar's takes over.
        let stage = DayScoreMorph.stage(progress, from: 0.2, to: 0.9)
        let move = reduceMotion ? 0 : CGFloat(stage * stage * (3 - 2 * stage))
        // The score sits above the label's middle while the caption is under it; it's the score that has to land.
        let labelSide = SegmentedDayRing.CentreLabel.size(innerDiameter: Self.ringInnerDiameter)
        let scoreOffset = ringScoreFrame.map { CGPoint(x: $0.midX - labelSide / 2, y: $0.midY - labelSide / 2) }
            ?? .zero
        let endScale = ringScoreFrame.map { $0.width > 0 ? barLabelWidth / $0.width : 0.5 } ?? 0.5
        let scale = 1 + (endScale - 1) * move
        let target = CGPoint(x: Self.barInset + barLabelWidth / 2 - scoreOffset.x * endScale,
                             y: rowY - scoreOffset.y * endScale)
        return ringLabelLayout(captionOpacity: 1 - DayScoreMorph.stage(progress, from: 0, to: 0.3))
            .scaleEffect(scale)
            // Fully there until the bar's label is: two half-faded copies on top of each other dimmed it.
            .opacity(reduceMotion ? 1 - DayScoreMorph.stage(progress, from: 0, to: 0.5) : (progress < 1 ? 1 : 0))
            .position(x: ring.center.x + (target.x - ring.center.x) * move,
                      y: ring.center.y + (target.y - ring.center.y) * move)
            .allowsHitTesting(false)
    }

    /// The card's ring is 116 pt.
    private static let ringSide: CGFloat = 116
    private static let ringInnerDiameter = SegmentedDayRing.innerDiameter(side: ringSide,
                                                                          lineWidth: DayScoreMorph.cardRing.lineWidth)

    /// The ring's label as `SegmentedDayRing` lays it out in the card.
    private func ringLabelLayout(captionOpacity: Double = 1,
                                 onScoreFrame: ((CGRect) -> Void)? = nil) -> SegmentedDayRing.CentreLabel {
        SegmentedDayRing.CentreLabel(met: score.met, total: score.total,
                                     caption: "\(GoalProgress.goals(score.total)) met", side: Self.ringSide,
                                     innerDiameter: Self.ringInnerDiameter,
                                     captionOpacity: captionOpacity, onScoreFrame: onScoreFrame)
    }

    /// The bar's "3/6", coloured like the ring's.
    private var barLabel: some View {
        Text("\(Text("\(score.met)").foregroundStyle(Theme.onForestPrimary))\(Text("/\(score.total)").foregroundStyle(Theme.onForestSecondary))")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barLabelWidth = $0 }
    }

    private var barStreak: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.greenSoft)
            Text("\(streak ?? 0)")
                .monospacedDigit()
                .foregroundStyle(Theme.onForestPrimary)
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barStreakWidth = $0 }
    }

    /// "3 of 5 goals met, 10-day streak", as the card reads.
    private var accessibilityText: String {
        let goals = score.total > 0 ? "\(score.met) of \(score.total) \(GoalProgress.goals(score.total)) met" : score.title
        guard let streak, streak >= 1 else { return goals }
        return "\(goals), \(streak)-day streak"
    }
}

// MARK: - Previews

#Preview("Collapsing") {
    let score = DayScore(met: 3, total: 5)
    let cardHeight: CGFloat = 156
    ScrollView {
        VStack(spacing: 12) {
            DayScoreCard(score: score, streak: 10)
            ForEach([0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0], id: \.self) { progress in
                CollapsingDayScore(score: score, streak: 10, cardHeight: cardHeight,
                                   visibleHeight: cardHeight - (cardHeight - 44) * progress)
            }
            CollapsingDayScore(score: DayScore(met: 7, total: 15), streak: 3, cardHeight: cardHeight,
                               visibleHeight: 80)
            CollapsingDayScore(score: DayScore(met: 7, total: 15), streak: 3, cardHeight: cardHeight,
                               visibleHeight: 44)
        }
        .padding(16)
    }
    .background(Theme.surfaceGround)
}

#Preview("Collapsing, dark") {
    let score = DayScore(met: 4, total: 6)
    ScrollView {
        VStack(spacing: 12) {
            ForEach([0, 0.3, 0.6, 1.0], id: \.self) { progress in
                CollapsingDayScore(score: score, streak: 12, cardHeight: 156,
                                   visibleHeight: 156 - 112 * progress)
            }
        }
        .padding(16)
    }
    .background(Theme.surfaceGround)
    .preferredColorScheme(.dark)
}

#Preview("Collapsing, second half") {
    let cardHeight: CGFloat = 156
    VStack(spacing: 12) {
        ForEach([0.45, 0.6, 0.75, 0.9, 1.0], id: \.self) { progress in
            CollapsingDayScore(score: DayScore(met: 3, total: 5), streak: 10, cardHeight: cardHeight,
                               visibleHeight: cardHeight - (cardHeight - 44) * progress)
        }
        CollapsingDayScore(score: DayScore(met: 7, total: 15), streak: 3, cardHeight: cardHeight, visibleHeight: 80)
        CollapsingDayScore(score: DayScore(met: 7, total: 15), streak: 3, cardHeight: cardHeight, visibleHeight: 44)
        CollapsingDayScore(score: DayScore(met: 0, total: 1), cardHeight: cardHeight, visibleHeight: 44)
    }
    .padding(16)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.surfaceGround)
}
