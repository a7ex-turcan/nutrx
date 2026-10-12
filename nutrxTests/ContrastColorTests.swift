import SwiftUI
import XCTest
@testable import nutrx

/// WCAG contrast maths, and the heatmap's ink choice for every tint (DESIGN.md §4.8).
final class ContrastColorTests: XCTestCase {
    private let black = ContrastColor(red: 0, green: 0, blue: 0)

    private func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return environment
    }

    func testBlackOnWhiteIsTwentyOneToOne() {
        XCTAssertEqual(black.contrast(with: .white), 21, accuracy: 1e-9)
        XCTAssertEqual(ContrastColor.white.contrast(with: black), 21, accuracy: 1e-9)
        XCTAssertEqual(black.contrast(with: black), 1, accuracy: 1e-9)
    }

    func testBlendedMixesTowardTheBackground() {
        let mid = ContrastColor.white.blended(opacity: 0.25, over: black)
        XCTAssertEqual(mid, ContrastColor(red: 0.25, green: 0.25, blue: 0.25))
    }

    func testResolvedAssetColoursAreGammaEncodedSRGB() {
        // Text/OnTint is #050A07 — components must come back as 5/255, not linearised.
        let ink = ContrastColor(Theme.textOnTint, in: environment(.light))
        XCTAssertEqual(ink.red, 5.0 / 255, accuracy: 0.002)
        XCTAssertEqual(ink.green, 10.0 / 255, accuracy: 0.002)
        XCTAssertEqual(ink.blue, 7.0 / 255, accuracy: 0.002)
    }

    func testHeatmapInkMeetsAAForEveryTintAndFill() {
        let fills = [1, 0.7, 0.4, 0.15, WeekdayPattern.fillOpacity(for: nil)]
        for scheme in [ColorScheme.light, .dark] {
            for tint in NutrientTint.allCases {
                for opacity in fills {
                    let contrast = WeekdayHeatmap.ink(on: tint, opacity: opacity, in: environment(scheme)).contrast
                    XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(tint) at \(opacity) in \(scheme)")
                }
            }
        }
    }
}
