import XCTest
@testable import nutrx

/// This device's iCloud sync choice (#113): on by default, and the first launch with it keeps what this device's
/// old (synced) switch showed, but never turns a fresh install off.
final class ICloudSyncTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "icloud-sync-\(UUID())"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name)!
    }

    func testOnByDefault() {
        XCTAssertTrue(ICloudSync.isEnabled(defaults: freshDefaults()))
    }

    func testAnExistingStoreKeepsTheOldChoice() {
        let defaults = freshDefaults()
        ICloudSync.adoptLegacyChoice(storeExists: true, legacy: { false }, defaults: defaults)
        XCTAssertFalse(ICloudSync.isEnabled(defaults: defaults))
    }

    func testAFreshInstallStartsOnAndIgnoresALaterSyncedChoice() {
        let defaults = freshDefaults()
        ICloudSync.adoptLegacyChoice(storeExists: false, legacy: { false }, defaults: defaults)
        XCTAssertTrue(ICloudSync.isEnabled(defaults: defaults))
        // Another device's "off" arriving by sync later doesn't change it.
        ICloudSync.adoptLegacyChoice(storeExists: true, legacy: { false }, defaults: defaults)
        XCTAssertTrue(ICloudSync.isEnabled(defaults: defaults))
    }

    func testAnUnreadableStoreTriesAgainNextLaunch() {
        let defaults = freshDefaults()
        ICloudSync.adoptLegacyChoice(storeExists: true, legacy: { nil }, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: ICloudSync.enabledKey))
        ICloudSync.adoptLegacyChoice(storeExists: true, legacy: { false }, defaults: defaults)
        XCTAssertFalse(ICloudSync.isEnabled(defaults: defaults))
    }

    func testTheUsersChoiceWins() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: ICloudSync.enabledKey)
        ICloudSync.adoptLegacyChoice(storeExists: true, legacy: { false }, defaults: defaults)
        XCTAssertTrue(ICloudSync.isEnabled(defaults: defaults))
    }
}
