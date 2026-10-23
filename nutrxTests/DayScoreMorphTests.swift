import CoreGraphics
import XCTest
@testable import nutrx

/// Today's day-score card collapsing into the slim bar (#243).
final class DayScoreMorphTests: XCTestCase {
    private let line = DayScoreMorph.Line(start: CGPoint(x: 60, y: 22), length: 240, lineWidth: 6, gap: 3)
    private var morph: DayScoreMorph { DayScoreMorph(ring: DayScoreMorph.cardRing, line: line) }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func testProgressFollowsWhatsLeftOfTheCard() {
        XCTAssertEqual(DayScoreMorph.progress(visibleHeight: 156, cardHeight: 156, barHeight: 44), 0)
        XCTAssertEqual(DayScoreMorph.progress(visibleHeight: 100, cardHeight: 156, barHeight: 44), 0.5)
        XCTAssertEqual(DayScoreMorph.progress(visibleHeight: 44, cardHeight: 156, barHeight: 44), 1)
        XCTAssertEqual(DayScoreMorph.progress(visibleHeight: 200, cardHeight: 156, barHeight: 44), 0, "not yet pinned")
        XCTAssertEqual(DayScoreMorph.progress(visibleHeight: 10, cardHeight: 156, barHeight: 44), 1, "scrolled past")
        XCTAssertEqual(DayScoreMorph.stage(0.8, from: 0.6, to: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(DayScoreMorph.stage(0.2, from: 0.6, to: 1), 0)
    }

    /// At the start it's the card's ring, clockwise from the top, so the swap from the card is invisible.
    func testStartsAsTheRing() {
        let ring = DayScoreMorph.cardRing
        for fraction in stride(from: 0.0, through: 1.0, by: 0.05) {
            XCTAssertEqual(distance(morph.point(at: fraction, progress: 0), ring.center), ring.radius, accuracy: 1e-6)
        }
        let top = morph.point(at: 0, progress: 0), quarter = morph.point(at: 0.25, progress: 0)
        XCTAssertEqual(top.x, ring.center.x, accuracy: 1e-6)
        XCTAssertEqual(top.y, ring.center.y - ring.radius, accuracy: 1e-6)
        XCTAssertEqual(quarter.x, ring.center.x + ring.radius, accuracy: 1e-6, "clockwise: right at a quarter")
        XCTAssertEqual(morph.lineWidth(at: 0), ring.lineWidth)
    }

    /// At the end it's the bar's line, left to right, so met segments come first on the left.
    func testEndsAsTheLine() {
        for fraction in stride(from: 0.0, through: 1.0, by: 0.1) {
            let point = morph.point(at: fraction, progress: 1)
            XCTAssertEqual(point.y, line.start.y, accuracy: 1e-6)
            XCTAssertEqual(point.x, line.start.x + line.length * CGFloat(fraction), accuracy: 1e-6)
        }
        XCTAssertEqual(morph.lineWidth(at: 1), line.lineWidth)
    }

    /// Part way, what's unrolled lies on the line and the rest stays curled under it, never wider than the ring was.
    func testUnrollsAlongTheLine() {
        let progress = 0.5
        let anchor = morph.anchor(at: progress)
        let laid = morph.point(at: 0.2, progress: progress)
        XCTAssertEqual(laid.y, anchor.y, accuracy: 1e-6, "the first part is flat")
        let curled = morph.point(at: 0.9, progress: progress)
        XCTAssertGreaterThan(curled.y, anchor.y, "the rest hangs under the line")
        XCTAssertLessThan(morph.coilRadius(at: progress), DayScoreMorph.cardRing.radius)
        // Never curled past a full turn, even for a long line.
        let long = DayScoreMorph(ring: DayScoreMorph.cardRing,
                                 line: .init(start: CGPoint(x: 60, y: 22), length: 900, lineWidth: 6, gap: 3))
        for progress in stride(from: 0.0, through: 1.0, by: 0.05) {
            let remaining = long.length(at: progress) * CGFloat(1 - progress)
            XCTAssertLessThanOrEqual(remaining, 2 * .pi * long.coilRadius(at: progress) + 1e-6)
        }
    }

    func testPiecesAreTheRingsSegments() {
        XCTAssertEqual(DayScoreMorph.pieces(met: 3, total: 5).map(\.isMet), [true, true, true, false, false])
        XCTAssertEqual(DayScoreMorph.pieces(met: 1, total: 4)[1], .init(from: 0.25, to: 0.5, isMet: false))
        // One goal, or more than 12: a continuous track with the met share over it, as SegmentedDayRing draws it.
        XCTAssertEqual(DayScoreMorph.pieces(met: 7, total: 14),
                       [.init(from: 0, to: 1, isMet: false), .init(from: 0, to: 0.5, isMet: true)])
        XCTAssertEqual(DayScoreMorph.pieces(met: 0, total: 1), [.init(from: 0, to: 1, isMet: false)])
        XCTAssertEqual(DayScoreMorph.pieces(met: 0, total: 0), [.init(from: 0, to: 1, isMet: false)])
    }

    /// Segments keep the ring's gaps at the start and the bar's 3 pt gaps at the end.
    func testSegmentGaps() throws {
        let pieces = DayScoreMorph.pieces(met: 2, total: 4)
        let first = try XCTUnwrap(morph.stroke(pieces[0], segmented: true, at: 1))
        let second = try XCTUnwrap(morph.stroke(pieces[1], segmented: true, at: 1))
        // Between the strokes' ends: the gap plus a cap's half width on each side.
        XCTAssertEqual(CGFloat(second.from - first.to) * line.length, 3 + 6, accuracy: 1e-6)
        let ring = DayScoreMorph.cardRing
        let ringFirst = try XCTUnwrap(morph.stroke(pieces[0], segmented: true, at: 0))
        let ringSecond = try XCTUnwrap(morph.stroke(pieces[1], segmented: true, at: 0))
        XCTAssertEqual(CGFloat(ringSecond.from - ringFirst.to) * 2 * .pi * ring.radius, ring.gap + ring.lineWidth,
                       accuracy: 1e-6)
    }

    /// The continuous track is the whole line at the end, its caps inside it.
    func testContinuousTrackFillsTheLine() throws {
        let track = try XCTUnwrap(morph.stroke(.init(from: 0, to: 1, isMet: false), segmented: false, at: 1))
        XCTAssertEqual(CGFloat(track.from) * line.length, 3, accuracy: 1e-6)
        XCTAssertEqual(CGFloat(1 - track.to) * line.length, 3, accuracy: 1e-6)
        let closed = try XCTUnwrap(morph.stroke(.init(from: 0, to: 1, isMet: false), segmented: false, at: 0))
        XCTAssertEqual(closed.from, 0)
        XCTAssertEqual(closed.to, 1)
    }
}
