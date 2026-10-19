import XCTest
@testable import nutrx

/// Today's "Enable notifications" banner (#44): when it shows, and that answering the permission prompt anywhere tells
/// Today to look again.
final class NotificationBannerTests: XCTestCase {
    func testShowsUntilAllowedOrClosed() {
        XCTAssertTrue(NotificationService.showsPermissionBanner(status: .notDetermined, hasSeenBanner: false))
        XCTAssertTrue(NotificationService.showsPermissionBanner(status: .notDetermined, hasSeenBanner: true),
                      "a reinstall resets the permission, not the synced flag")
        XCTAssertFalse(NotificationService.showsPermissionBanner(status: .granted, hasSeenBanner: false),
                       "allowed from Settings without closing the banner")
        XCTAssertFalse(NotificationService.showsPermissionBanner(status: .granted, hasSeenBanner: true))
        XCTAssertTrue(NotificationService.showsPermissionBanner(status: .denied, hasSeenBanner: false))
        XCTAssertFalse(NotificationService.showsPermissionBanner(status: .denied, hasSeenBanner: true))
    }

    func testAnsweringThePromptIsAnnounced() async {
        let announced = expectation(forNotification: .notificationPermissionAnswered, object: nil)
        let granted = await NotificationService.requestPermission(ask: { true })
        XCTAssertTrue(granted)
        await fulfillment(of: [announced], timeout: 5)
    }

    func testAFailedPromptIsStillAnnouncedAndNotGranted() async {
        struct PromptFailed: Error {}
        let announced = expectation(forNotification: .notificationPermissionAnswered, object: nil)
        let granted = await NotificationService.requestPermission(ask: { throw PromptFailed() })
        XCTAssertFalse(granted)
        await fulfillment(of: [announced], timeout: 5)
    }
}
