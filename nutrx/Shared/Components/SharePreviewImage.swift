import SwiftUI

/// A share sheet preview's image, drawn from a view: `SharePreview(_:image:)` takes an image, and without one the sheet
/// shows a generic placeholder beside the title (#270).
enum SharePreviewImage {
    /// A nutrient's tile, for sharing that nutrient ("Vitamin D: 120 × 1,000 IU").
    static func tile(for nutrient: Nutrient, scale: CGFloat, colorScheme: ColorScheme) -> Image {
        render(NutrientIconTile(nutrient: nutrient, size: size), scale: scale, colorScheme: colorScheme)
    }

    /// A list in the brand colours, for sharing several at once ("2 running low").
    static func list(scale: CGFloat, colorScheme: ColorScheme) -> Image {
        render(listTile, scale: scale, colorScheme: colorScheme)
    }

    private static let size: CGFloat = 60

    private static var listTile: some View {
        Image(systemName: "checklist")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.green)
            .frame(width: size * 22 / 42, height: size * 22 / 42)
            .frame(width: size, height: size)
            .background(Theme.forest,
                        in: RoundedRectangle(cornerRadius: size * Theme.Radius.iconTile / 40, style: .continuous))
    }

    private static func render(_ content: some View, scale: CGFloat, colorScheme: ColorScheme) -> Image {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, colorScheme))
        renderer.scale = scale
        // Not expected to fail for a small view; the plain symbol keeps a preview if it ever does.
        return renderer.uiImage.map(Image.init(uiImage:)) ?? Image(systemName: "list.bullet")
    }
}
