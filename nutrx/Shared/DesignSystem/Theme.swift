import SwiftUI

/// The nutrx brand layer (DESIGN.md §1). Redesigned views take every colour, spacing and radius from here —
/// no hex values or layout literals in view code. Colours are named sets in `Colors.xcassets` with
/// Any/Dark appearances; that catalog and this file are members of the app, widget and Watch targets.
enum Theme {

    // MARK: - Brand
    static let forest = color(.brandForest)
    /// Fills only (done states, met segments, check badges) — never text on light backgrounds. Use `textGreenInk` for text.
    static let green = color(.brandGreen)
    static let greenSoft = color(.brandGreenSoft)

    // MARK: - Text
    static let textPrimary = color(.textPrimary)
    static let textSecondary = color(.textSecondary)
    static let textGreenInk = color(.textGreenInk)
    static let textAmberInk = color(.textAmberInk)
    /// Dark ink for text on a strong nutrient-tint fill (same in light and dark).
    static let textOnTint = color(.textOnTint)

    // MARK: - Status
    static let statusAmber = color(.statusAmber)

    // MARK: - Surfaces & lines
    static let surfaceGround = color(.surfaceGround)
    static let surfaceCard = color(.surfaceCard)
    static let surfaceChip = color(.surfaceChip)
    static let lineHairline = color(.lineHairline)

    // MARK: - Controls
    static let controlGhostBorder = color(.controlGhostBorder)
    static let controlPrimary = color(.controlPrimary)
    static let controlOnPrimary = color(.controlOnPrimary)

    // MARK: - On forest (day-score card, streak card, welcome)
    static let onForestPrimary = color(.onForestPrimary)
    static let onForestSecondary = color(.onForestSecondary)
    static let onForestTrack = color(.onForestTrack)

    // MARK: - Watch
    static let watchCell = color(.watchCell)

    // MARK: - Profile avatar
    static let avatarFill = color(.avatarFill)
    static let avatarInk = color(.avatarInk)

    // MARK: - Shape & spacing (§1.4)
    enum Spacing {
        static let screenMargin: CGFloat = 16
        static let cardGap: CGFloat = 10
        static let cardPadding: CGFloat = 14
        /// Space above a group header.
        static let sectionTop: CGFloat = 22
    }

    enum Radius {
        static let card: CGFloat = 22
        /// Day-score and streak cards.
        static let hero: CGFloat = 28
        static let iconTile: CGFloat = 12
        /// Text fields, full-width primary buttons and the goal-type cards.
        static let control: CGFloat = 16
        /// Small tags such as "AT LEAST".
        static let tag: CGFloat = 6
    }

    /// Minimum hit area for anything tappable.
    static let minTouchTarget: CGFloat = 44

    // MARK: - Assets

    /// Asset-catalog names of the §1.1 tokens.
    enum ColorAsset: String, CaseIterable {
        case brandForest = "Brand/Forest"
        case brandGreen = "Brand/Green"
        case brandGreenSoft = "Brand/GreenSoft"
        case textPrimary = "Text/Primary"
        case textSecondary = "Text/Secondary"
        case textGreenInk = "Text/GreenInk"
        case textAmberInk = "Text/AmberInk"
        case textOnTint = "Text/OnTint"
        case statusAmber = "Status/Amber"
        case surfaceGround = "Surface/Ground"
        case surfaceCard = "Surface/Card"
        case surfaceChip = "Surface/Chip"
        case lineHairline = "Line/Hairline"
        case controlGhostBorder = "Control/GhostBorder"
        case controlPrimary = "Control/Primary"
        case controlOnPrimary = "Control/OnPrimary"
        case onForestPrimary = "OnForest/Primary"
        case onForestSecondary = "OnForest/Secondary"
        case onForestTrack = "OnForest/Track"
        case watchCell = "Watch/Cell"
        case avatarFill = "Avatar/Fill"
        case avatarInk = "Avatar/Ink"
    }

    private static func color(_ asset: ColorAsset) -> Color {
        Color(asset.rawValue)
    }
}

// MARK: - Nutrient tints (§1.2)

extension NutrientTint {
    /// The colour sets each tint has in `Colors.xcassets`.
    enum Swatch: String, CaseIterable {
        case ring = ""
        case tile = "Tile"
        case glyph = "Glyph"
        case track = "Track"
    }

    /// Ring, chart and glyph colour.
    var color: Color { Color(assetName(.ring)) }
    /// Icon-tile background (dark: tint @ 18% over `Surface/Card`).
    var tileBackground: Color { Color(assetName(.tile)) }
    /// Glyph drawn on `tileBackground` (dark: the tint itself).
    var tileGlyph: Color { Color(assetName(.glyph)) }
    /// Unfilled part of a ring: tint @ 15% (light) / 20% (dark).
    var trackColor: Color { Color(assetName(.track)) }

    func assetName(_ swatch: Swatch) -> String {
        "Tint/\(rawValue.capitalized)\(swatch.rawValue)"
    }
}

// MARK: - Status colours (§2)

extension GoalStatus {
    /// Ring colour: the nutrient's tint, or `Status/Amber` when nearing or over a limit.
    func ringColor(tint: NutrientTint) -> Color {
        switch self {
        case .nearingLimit, .overLimit: Theme.statusAmber
        case .inProgress, .met: tint.color
        }
    }

    /// Colour of the status line under a nutrient's value.
    var textColor: Color {
        switch self {
        case .met: Theme.textGreenInk
        case .nearingLimit, .overLimit: Theme.textAmberInk
        case .inProgress: Theme.textSecondary
        }
    }
}
