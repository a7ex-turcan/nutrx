import UIKit
import XCTest
@testable import nutrx

/// The app icons (nutrx Pro, #139): every alternate is built into the app under its name, has a preview, and goes
/// back to the default without Pro.
final class AppIconChoiceTests: XCTestCase {
    func testTheDefaultAndSixAlternates() {
        XCTAssertNil(AppIconChoice.forest.alternateIconName, "the default is the app's own icon")
        let names = AppIconChoice.allCases.compactMap(\.alternateIconName)
        XCTAssertEqual(names, ["AppIcon-Light", "AppIcon-Mint", "AppIcon-Midnight", "AppIcon-Botanical",
                               "AppIcon-Sunrise", "AppIcon-Mono"])
        XCTAssertEqual(AppIconChoice.allCases.map(\.title),
                       ["Forest", "Light", "Mint", "Midnight", "Botanical", "Sunrise", "Mono"])
    }

    /// Each alternate is in the built app's Info.plist (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`), or
    /// `setAlternateIconName` fails for it.
    func testEveryAlternateIsBuiltIntoTheApp() throws {
        let icons = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any],
                                       "No alternate icons in the app's Info.plist")
        for name in AppIconChoice.allCases.compactMap(\.alternateIconName) {
            XCTAssertNotNil(alternates[name], "\(name) isn't an alternate icon of the app")
        }
    }

    func testEveryIconHasAPreview() {
        for icon in AppIconChoice.allCases {
            XCTAssertNotNil(UIImage(named: icon.previewImageName), "No preview for \(icon.title)")
        }
    }

    func testTheCurrentIcon() {
        XCTAssertEqual(AppIconChoice.current(alternateIconName: nil), .forest)
        XCTAssertEqual(AppIconChoice.current(alternateIconName: "AppIcon-Midnight"), .midnight)
        XCTAssertEqual(AppIconChoice.current(alternateIconName: "AppIcon-Gone"), .forest, "an icon since removed")
    }

    func testWithoutProTheDefaultComesBack() {
        XCTAssertTrue(AppIconChoice.shouldReset(alternateIconName: "AppIcon-Mint", isPro: false))
        XCTAssertFalse(AppIconChoice.shouldReset(alternateIconName: "AppIcon-Mint", isPro: true))
        XCTAssertFalse(AppIconChoice.shouldReset(alternateIconName: nil, isPro: false), "the default already")
    }
}
