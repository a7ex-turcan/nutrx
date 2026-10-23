import Foundation

/// "What's new" on Today after an update (#148): a one-time card per release that has something worth showing,
/// written here per version. Pure, tested in `WhatsNewTests`.
nonisolated struct WhatsNew: Equatable {
    /// The release it belongs to ("2.3"); its patch versions ("2.3.1") show the same card.
    let version: String
    let items: [Item]

    struct Item: Equatable {
        let title: String
        let subtitle: String
        let symbolName: String
        let tint: NutrientTint
        /// A Pro feature shows the PRO chip; the card itself never opens the paywall.
        var isPro = false
        /// Shown only on iPad, where it's something the reader will see.
        var iPadOnly = false
    }

    var title: String { "New in \(version)" }

    /// The release whose card was closed, or seen at onboarding, on this device (per device, never synced).
    static let hiddenVersionKey = "nutrx.whatsNewHiddenVersion"

    /// Every release with a card, newest last.
    static let releases: [WhatsNew] = [
        WhatsNew(version: "2.3", items: [
            Item(title: "Built for iPad", subtitle: "Two columns on Today, and your nutrients and history side by side.",
                 symbolName: "ipad.landscape", tint: .blue, iPadOnly: true),
            Item(title: "Last day of a course", subtitle: "Today says when a course ends, so it's no surprise.",
                 symbolName: "hourglass", tint: .green, isPro: true),
        ]),
        WhatsNew(version: "2.4", items: [
            Item(title: "Schedules", subtitle: "Take something on set days, every few days, on and off, or a few times a week.",
                 symbolName: "calendar.badge.clock", tint: .pink, isPro: true),
            Item(title: "Suggest a feature", subtitle: "Tell us what you'd like next, from Settings.",
                 symbolName: "lightbulb", tint: .teal),
        ]),
        WhatsNew(version: "2.5", items: [
            Item(title: "What your supply costs",
                 subtitle: "Add a price per bottle to see what it costs a month, and add what's running low to Reminders.",
                 symbolName: "creditcard", tint: .amber, isPro: true),
        ]),
    ]

    /// The card to show, if any: the release `appVersion` belongs to (its first two numbers), with only the items
    /// for this device, unless it was hidden here. Onboarding marks the release it ran on as hidden
    /// (`markSeenAtOnboarding`), so a fresh install never shows one; a new device restored from iCloud skips
    /// onboarding and does.
    static func card(appVersion: String, hiddenVersion: String?, isPad: Bool,
                     releases: [WhatsNew] = releases) -> WhatsNew? {
        let release = majorMinor(appVersion)
        guard let card = releases.first(where: { $0.version == release }), hiddenVersion != card.version else {
            return nil
        }
        let items = card.items.filter { isPad || !$0.iPadOnly }
        return items.isEmpty ? nil : WhatsNew(version: card.version, items: items)
    }

    /// A fresh install has nothing "new" to compare with: the release onboarding ran on counts as seen.
    static func markSeenAtOnboarding(appVersion: String, defaults: UserDefaults) {
        defaults.set(majorMinor(appVersion), forKey: hiddenVersionKey)
    }

    /// "2.3.1" → "2.3".
    static func majorMinor(_ version: String) -> String {
        version.split(separator: ".").prefix(2).joined(separator: ".")
    }
}
