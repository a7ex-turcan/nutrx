import CoreGraphics

/// The paywall's plan line above the pinned button (#338): shown only while the selected plan's card isn't wholly in
/// view (pure).
enum PlanLine {
    /// The footer's padding above the pinned button: the footer, and its hairline, start this far above it.
    static let margin: CGFloat = 10

    /// Whether the line shows: any of the selected card is above the sheet's top or below the footer's top, `margin`
    /// above the pinned button's. The whole card, not its middle (#352): opened from Settings, a sheet on a sheet, the
    /// paywall sits about 20 pt lower, and on an SE Yearly's bottom edge went under the footer with nothing naming the
    /// plan. Measured against the button, which stays put when the line comes and goes, so showing it can't hide the
    /// card and keep itself showing. Not measured yet (the frame after the plans load), it's hidden.
    static func shows(card: ClosedRange<CGFloat>?, sheetTop: CGFloat, buttonTop: CGFloat?) -> Bool {
        guard let card, let buttonTop else { return false }
        return !(card.lowerBound >= sheetTop && card.upperBound <= buttonTop - margin)
    }
}
