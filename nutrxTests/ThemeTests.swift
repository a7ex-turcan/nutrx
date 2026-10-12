import UIKit
import XCTest
@testable import nutrx

/// DESIGN.md §1 — every colour `Theme` refers to exists in the asset catalog, with a dark variant where the spec has one.
final class ThemeTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    func testEveryTokenExistsInTheAssetCatalog() {
        for asset in Theme.ColorAsset.allCases {
            XCTAssertNotNil(UIColor(named: asset.rawValue, in: .main, compatibleWith: nil), asset.rawValue)
        }
    }

    func testEveryTintSwatchExistsInTheAssetCatalog() {
        for tint in NutrientTint.allCases {
            for swatch in NutrientTint.Swatch.allCases {
                let name = tint.assetName(swatch)
                XCTAssertNotNil(UIColor(named: name, in: .main, compatibleWith: nil), name)
            }
        }
    }

    func testTintAssetNames() {
        XCTAssertEqual(NutrientTint.green.assetName(.ring), "Tint/Green")
        XCTAssertEqual(NutrientTint.indigo.assetName(.tile), "Tint/IndigoTile")
        XCTAssertEqual(NutrientTint.coral.assetName(.glyph), "Tint/CoralGlyph")
        XCTAssertEqual(NutrientTint.brown.assetName(.track), "Tint/BrownTrack")
    }

    func testSurfacesAndTextChangeInDarkMode() throws {
        for asset in [Theme.ColorAsset.surfaceGround, .surfaceCard, .textPrimary, .textSecondary, .textGreenInk, .controlPrimary] {
            let color = try XCTUnwrap(UIColor(named: asset.rawValue, in: .main, compatibleWith: nil))
            XCTAssertNotEqual(color.resolvedColor(with: light), color.resolvedColor(with: dark), asset.rawValue)
        }
    }

    func testBrandColoursMatchTheSpec() throws {
        assertHex(.brandForest, light: 0x1B3B2D, dark: 0x1B3B2D)
        assertHex(.brandGreen, light: 0x1EB955, dark: 0x1EB955)
        assertHex(.textGreenInk, light: 0x137A3A, dark: 0x5BD88A)
        assertHex(.surfaceGround, light: 0xF2F4EF, dark: 0x0A130E)
    }

    private func assertHex(_ asset: Theme.ColorAsset, light lightHex: Int, dark darkHex: Int,
                           file: StaticString = #filePath, line: UInt = #line) {
        guard let color = UIColor(named: asset.rawValue, in: .main, compatibleWith: nil) else {
            return XCTFail("missing \(asset.rawValue)", file: file, line: line)
        }
        XCTAssertEqual(hex(color.resolvedColor(with: light)), lightHex, "\(asset.rawValue) light", file: file, line: line)
        XCTAssertEqual(hex(color.resolvedColor(with: dark)), darkHex, "\(asset.rawValue) dark", file: file, line: line)
    }

    private func hex(_ color: UIColor) -> Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Int((r * 255).rounded()) << 16 | Int((g * 255).rounded()) << 8 | Int((b * 255).rounded())
    }
}
