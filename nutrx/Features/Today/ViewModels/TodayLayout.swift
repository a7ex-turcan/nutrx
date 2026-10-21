import CoreGraphics

/// Which Today layout a width gets on large screens (docs/design/large-screens/LAYOUT.md, #152). Pure, tested in
/// `TodayLayoutTests`.
nonisolated enum TodayLayout: Equatable {
    /// The iPhone list (compact widths, and the largest text sizes on any width).
    case list
    /// Two card columns under the score, cards and stack tiles.
    case columns
    /// A 360 pt side column beside two card columns, the whole capped at 1120 pt.
    case sideColumn

    static let sideColumnWidth: CGFloat = 360
    /// Between the side column and the card columns.
    static let sideColumnGap: CGFloat = 24
    static let maxContentWidth: CGFloat = 1120
    /// A nutrient card needs 320 pt for its ring, two lines and both 44 pt buttons.
    static let minimumCardWidth: CGFloat = 320

    /// The side column needs 40 + 360 + 24 + 320 + 20 + 320 + 40 = 1124 pt. A 13-inch iPad in portrait (1032 pt) is
    /// wide but gets the columns: with the side column its cards were 274 pt and broke names mid-word.
    static let sideColumnMinimum: CGFloat = 2 * WidthClass.wide.minimumMargin + sideColumnWidth + sideColumnGap
        + 2 * minimumCardWidth + gutter(.wide)

    /// Between card columns and stack tiles: 16 pt, 20 on wide.
    static func gutter(_ widthClass: WidthClass) -> CGFloat { widthClass == .wide ? 20 : 16 }

    static func of(width: CGFloat, isAccessibilitySize: Bool) -> TodayLayout {
        if isAccessibilitySize || WidthClass(width: width) == .compact { return .list }
        return width >= sideColumnMinimum ? .sideColumn : .columns
    }
}
