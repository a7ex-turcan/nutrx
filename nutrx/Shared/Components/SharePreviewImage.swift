import SwiftUI

/// A share sheet preview's image, drawn from a view: `SharePreview(_:image:)` takes an image, and without one the sheet
/// shows a generic placeholder beside the title (#270). iOS shows it at 32 pt in a white frame of its own.
enum SharePreviewImage {
    /// A nutrient's tile, for sharing that nutrient ("Vitamin D: 120 × 1,000 IU").
    static func tile(tint: NutrientTint, symbolName: String, scale: CGFloat, colorScheme: ColorScheme) -> Image {
        render(NutrientIconTile(tint: tint, symbolName: symbolName, size: size), scale: scale, colorScheme: colorScheme)
    }

    /// A list in the brand colours, for sharing several at once ("2 running low").
    static func list(scale: CGFloat, colorScheme: ColorScheme) -> Image {
        render(listTile, scale: scale, colorScheme: colorScheme)
    }

    /// Until an image is drawn, and if drawing ever fails.
    static let placeholder = Image(systemName: "checklist")

    private static let size: CGFloat = 60

    fileprivate static var listTile: some View {
        NutrientIconTile(glyph: Theme.green, background: Theme.forest, symbolName: "checklist", size: size)
    }

    private static func render(_ content: some View, scale: CGFloat, colorScheme: ColorScheme) -> Image {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, colorScheme))
        renderer.scale = scale
        return renderer.uiImage.map(Image.init(uiImage:)) ?? placeholder
    }
}

/// What a drawn preview depends on, for `.task(id:)`: a new appearance or display scale draws it again.
struct SharePreviewImageKey: Hashable {
    var colorScheme: ColorScheme
    var scale: CGFloat
    var tint: NutrientTint? = nil
    var symbolName: String? = nil
}

// MARK: - Previews

#Preview("Light") {
    SharePreviewImagePreviewGallery()
}

#Preview("Dark") {
    SharePreviewImagePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SharePreviewImagePreviewGallery: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // The images as drawn, and as the share sheet frames them (32 pt in a white 64 pt tile).
        HStack(spacing: 24) {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                VStack(spacing: 12) {
                    image
                    image
                        .resizable()
                        .frame(width: 32, height: 32)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(Theme.Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }

    private var images: [Image] {
        [SharePreviewImage.tile(tint: .amber, symbolName: "sun.max", scale: displayScale, colorScheme: colorScheme),
         SharePreviewImage.tile(tint: .teal, symbolName: "fish", scale: displayScale, colorScheme: colorScheme),
         SharePreviewImage.list(scale: displayScale, colorScheme: colorScheme)]
    }
}
