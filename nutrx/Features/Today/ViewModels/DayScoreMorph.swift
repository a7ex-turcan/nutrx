import CoreGraphics
import Foundation

/// The day-score card collapsing into the slim bar as Today scrolls (#243): how far along it is, and where each
/// piece of the ring is as it unrolls into the bar's line. Pure, so the geometry can be tested.
///
/// The ring unrolls like a tape measure: its start stays at the top, where the bar's line begins, and the ring rolls
/// right along the underside of the line, laying its segments flat behind it, met ones first, as the bar reads.
/// It shrinks as it goes, so it fits the card closing around it.
struct DayScoreMorph {
    /// The ring as `SegmentedDayRing` draws it in the card: a circle through the middle of its stroke.
    struct Ring: Equatable {
        var center: CGPoint
        var radius: CGFloat
        var lineWidth: CGFloat
        /// The visual gap between segments.
        var gap: CGFloat
    }

    /// The bar's line: through the middle of its stroke, from the left end of the first segment to the right end
    /// of the last.
    struct Line: Equatable {
        var start: CGPoint
        var length: CGFloat
        var lineWidth: CGFloat
        var gap: CGFloat
    }

    /// A stretch of the ring, in fractions of the whole (0 at the top, clockwise), drawn green when met.
    struct Piece: Equatable {
        var from: Double
        var to: Double
        var isMet: Bool
    }

    let ring: Ring
    let line: Line

    /// The card's 116 pt ring at its place in the card (20 pt padding), with `SegmentedDayRing`'s proportions.
    static let cardRing = Ring(center: CGPoint(x: 20 + 58, y: 20 + 58), radius: 50, lineWidth: 11, gap: 6)

    // MARK: - Progress

    /// How collapsed the card is: 0 while it's whole, 1 once it's down to the bar. The visible card shrinks from the
    /// bottom as it scrolls under the pinned top, from `cardHeight` to `barHeight`.
    static func progress(visibleHeight: CGFloat, cardHeight: CGFloat, barHeight: CGFloat) -> Double {
        guard cardHeight > barHeight else { return 1 }
        return min(max(Double((cardHeight - visibleHeight) / (cardHeight - barHeight)), 0), 1)
    }

    /// Part of `progress` mapped onto 0…1, for things that happen in a stretch of it (a fade from 0.6 to 1).
    static func stage(_ progress: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return progress >= end ? 1 : 0 }
        return min(max((progress - start) / (end - start), 0), 1)
    }

    // MARK: - Pieces

    /// Whether the ring is drawn as segments, as `SegmentedDayRing` does for 2 to 12 goals; otherwise one
    /// continuous track with the met share over it.
    static func isSegmented(total: Int) -> Bool {
        total > 1 && total <= SegmentedDayRing.maxSegments
    }

    /// One piece per goal, met ones first; or the whole track and the met share on top of it.
    static func pieces(met: Int, total: Int) -> [Piece] {
        let total = max(total, 0)
        let met = min(max(met, 0), total)
        if isSegmented(total: total) {
            let share = 1 / Double(total)
            return (0..<total).map { Piece(from: Double($0) * share, to: Double($0 + 1) * share, isMet: $0 < met) }
        }
        var pieces = [Piece(from: 0, to: 1, isMet: false)]
        if total > 0, met > 0 { pieces.append(Piece(from: 0, to: Double(met) / Double(total), isMet: true)) }
        return pieces
    }

    // MARK: - Geometry

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }

    /// The stroke's width at `progress`.
    func lineWidth(at progress: Double) -> CGFloat {
        Self.lerp(ring.lineWidth, line.lineWidth, progress)
    }

    /// Length of the whole curve: the ring's circumference, becoming the line's length.
    func length(at progress: Double) -> CGFloat {
        Self.lerp(2 * .pi * ring.radius, line.length, progress)
    }

    /// The piece's stroke, trimmed so round caps and the gap between segments come out as in the ring and the
    /// bar: from and to in fractions of the whole. Nil when nothing is left to draw.
    func stroke(_ piece: Piece, segmented: Bool, at progress: Double) -> (from: Double, to: Double)? {
        let length = Double(length(at: progress))
        guard length > 0 else { return nil }
        let width = Double(lineWidth(at: progress))
        if segmented {
            // Each end gives up half the gap and the cap's half width.
            let gap = Double(Self.lerp(ring.gap, line.gap, progress))
            let trim = (gap + width) / 2 / length
            let from = piece.from + trim, to = piece.to - trim
            return to > from ? (from, to) : nil
        }
        // The closed ring's track has no ends, and its met share runs from the top with round caps. On the line both
        // keep their caps inside their length, so the track is exactly the line and the share starts at its left end.
        let trim = width / 2 / length * progress
        let from = piece.from + trim
        return (from, max(piece.to - trim, from))
    }

    /// Where the unrolled part starts: the top of the ring, moving to the left end of the line.
    func anchor(at progress: Double) -> CGPoint {
        CGPoint(x: Self.lerp(ring.center.x, line.start.x, progress),
                y: Self.lerp(ring.center.y - ring.radius, line.start.y, progress))
    }

    /// The radius of what's still rolled up: smaller as it goes, but never so small that the rest would wrap round
    /// more than once (a long line on a wide screen).
    func coilRadius(at progress: Double) -> CGFloat {
        let remaining = length(at: progress) * CGFloat(1 - progress)
        return max(ring.radius * CGFloat(1 - 0.7 * progress), remaining / (2 * .pi))
    }

    /// Where the point `fraction` of the way round the ring (0 at the top, clockwise) is at `progress`.
    func point(at fraction: Double, progress: Double) -> CGPoint {
        let length = length(at: progress)
        let laid = length * CGFloat(progress)
        let along = length * CGFloat(fraction)
        let anchor = anchor(at: progress)
        // Already laid flat along the line.
        if along <= laid { return CGPoint(x: anchor.x + along, y: anchor.y) }
        // Still rolled up: round the coil hanging under the line, clockwise from where it touches it.
        let radius = coilRadius(at: progress)
        let angle = Double((along - laid) / radius)
        return CGPoint(x: anchor.x + laid + radius * CGFloat(sin(angle)),
                       y: anchor.y + radius - radius * CGFloat(cos(angle)))
    }

    /// The piece's stroke as points along it, close enough together to draw as a smooth curve.
    func points(from: Double, to: Double, progress: Double) -> [CGPoint] {
        let count = max(2, Int(((to - from) * 96).rounded(.up)) + 1)
        return (0..<count).map { point(at: from + (to - from) * Double($0) / Double(count - 1), progress: progress) }
    }
}
