import CoreGraphics

/// The paywall's plan line above the pinned button (#338): shown only while the selected plan's card is out of view
/// (pure).
enum PlanLine {
    /// How far above the pinned button's top a card's middle has to be to count as in view.
    static let margin: CGFloat = 10

    /// Whether the line shows: the selected card's middle is above the sheet's top, or below `margin` above the
    /// pinned button's top. Measured against the button, which stays put when the line comes and goes, so showing it
    /// can't hide the card and keep itself showing. Not measured yet (the frame after the plans load), it's hidden.
    static func shows(cardMidY: CGFloat?, sheetTop: CGFloat, buttonTop: CGFloat?) -> Bool {
        guard let cardMidY, let buttonTop else { return false }
        return !(cardMidY > sheetTop && cardMidY < buttonTop - margin)
    }
}
