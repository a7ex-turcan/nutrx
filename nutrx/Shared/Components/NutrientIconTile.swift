import SwiftUI

/// Rounded-square tile with a nutrient's symbol on its tint's tile colour (DESIGN.md §4.7).
/// 42pt in My Nutrients, 40pt on History day, 52pt in the analytics header.
struct NutrientIconTile: View {
    /// The tint's glyph and tile colours, or other colours for a tile that isn't a tint's (the share sheet's list
    /// tile, #270).
    let glyph: Color
    let background: Color
    let symbolName: String
    var size: CGFloat = 42

    var body: some View {
        // Symbol fits a 22pt box in a 42pt tile (design source), same as ProgressRing.
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .fontWeight(.regular)
            .foregroundStyle(glyph)
            .frame(width: size * 22 / 42, height: size * 22 / 42)
            .frame(width: size, height: size)
            .background(background,
                        in: RoundedRectangle(cornerRadius: size * Theme.Radius.iconTile / 40, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension NutrientIconTile {
    init(tint: NutrientTint, symbolName: String, size: CGFloat = 42) {
        self.init(glyph: tint.tileGlyph, background: tint.tileBackground, symbolName: symbolName, size: size)
    }

    init(nutrient: Nutrient, size: CGFloat = 42) {
        self.init(tint: nutrient.tint, symbolName: nutrient.symbolName, size: size)
    }
}

// MARK: - Previews

private struct NutrientIconTilePreviewGallery: View {
    private let samples: [(NutrientTint, String)] = [
        (.green, "waterbottle"), (.teal, "fish"), (.blue, "drop"), (.indigo, "pills"),
        (.pink, "heart"), (.coral, "dumbbell"), (.amber, "sun.max"), (.brown, "cup.and.saucer"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(42), spacing: 14), count: 4), alignment: .leading, spacing: 14) {
                ForEach(samples, id: \.0) { tint, symbol in
                    NutrientIconTile(tint: tint, symbolName: symbol)
                }
            }
            HStack(spacing: 14) {
                NutrientIconTile(tint: .amber, symbolName: "sun.max", size: 52)
                NutrientIconTile(tint: .teal, symbolName: "fish", size: 40)
                NutrientIconTile(tint: .indigo, symbolName: "brain.head.profile", size: 42)
                NutrientIconTile(tint: .green, symbolName: "figure.run", size: 42)
            }
        }
        .padding(Theme.Spacing.screenMargin)
        .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(Theme.Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    NutrientIconTilePreviewGallery()
}

#Preview("Dark") {
    NutrientIconTilePreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    NutrientIconTilePreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}
