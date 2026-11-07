import Foundation

/// nutrx's app icons (nutrx Pro, #139): the forest default and six alternates. Each is the app icon's own "n+" mark,
/// never redrawn, on another background (`Tools/AppIcons`). Pure: `AppIconSettingsView` sets one through
/// `UIApplication.setAlternateIconName`. Tested in `AppIconChoiceTests`.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case forest, light, mint, midnight, botanical, sunrise, mono

    var id: Self { self }

    /// "Forest", "Midnight".
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Its alternate icon set, listed in the app target's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; nil for
    /// the default.
    var alternateIconName: String? {
        self == .forest ? nil : "AppIcon-\(title)"
    }

    /// The picker's 180 px image: an app icon set can't be loaded as an image.
    var previewImageName: String { "AppIconPreview-\(title)" }

    /// The icon the system has set (`UIApplication.alternateIconName`, nil for the default).
    static func current(alternateIconName: String?) -> AppIconChoice {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .forest
    }

    /// Back to the default once a device knows Pro isn't active: the alternates are Pro.
    static func shouldReset(alternateIconName: String?, isPro: Bool) -> Bool {
        !isPro && alternateIconName != nil
    }
}
