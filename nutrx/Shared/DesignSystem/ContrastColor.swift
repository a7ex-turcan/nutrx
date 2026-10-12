import SwiftUI

/// An sRGB colour for WCAG 2 contrast checks — for picking legible text on fills that are only known at
/// runtime, like a nutrient tint at 70% over a card.
struct ContrastColor: Equatable {
    /// Gamma-encoded sRGB components, 0...1.
    let red: Double
    let green: Double
    let blue: Double

    static let white = ContrastColor(red: 1, green: 1, blue: 1)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ resolved: Color.Resolved) {
        self.init(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }

    /// Resolves `color` for the given environment (light / dark, contrast settings).
    init(_ color: Color, in environment: EnvironmentValues) {
        self.init(color.resolve(in: environment))
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.040_45 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, 1...21.
    func contrast(with other: ContrastColor) -> Double {
        let (lighter, darker) = luminance > other.luminance
            ? (luminance, other.luminance) : (other.luminance, luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This colour drawn at `opacity` over `background`.
    func blended(opacity: Double, over background: ContrastColor) -> ContrastColor {
        func mix(_ top: Double, _ bottom: Double) -> Double { top * opacity + bottom * (1 - opacity) }
        return ContrastColor(red: mix(red, background.red), green: mix(green, background.green),
                             blue: mix(blue, background.blue))
    }
}
