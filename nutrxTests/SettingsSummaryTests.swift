import XCTest
@testable import nutrx

/// DESIGN.md §5.9 — the values on the Settings rows and the profile card title.
final class SettingsSummaryTests: XCTestCase {

    func testICloud() {
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, enabled: true, active: true), "On")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, enabled: false, active: false), "Off")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, enabled: false, active: true), "Turning off")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, enabled: true, active: false), "Turning on")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: false, enabled: true, active: true), "No account")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, enabled: true, active: false, couldNotConnect: true),
                       "Couldn't connect")

        // This launch vs this device's choice (applies when nutrx next opens).
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: true, enabled: true, active: true), "Syncing")
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: true, enabled: false, active: false), "Off")
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: true, enabled: false, active: true),
                       "Stops when you reopen nutrx")
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: true, enabled: true, active: false),
                       "Starts when you reopen nutrx")
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: false, enabled: true, active: false), "No iCloud account")
        XCTAssertTrue(SettingsSummary.iCloudFooter(enabled: false, active: true).hasPrefix("Close nutrx from the app switcher"))
        XCTAssertFalse(SettingsSummary.iCloudFooter(enabled: false, active: false).contains("app switcher"))
        // On, but the CloudKit store failed to open at launch: not "Starts when you reopen".
        XCTAssertEqual(SettingsSummary.iCloudStatus(hasAccount: true, enabled: true, active: false, couldNotConnect: true),
                       "Couldn't connect")
        XCTAssertTrue(SettingsSummary.iCloudFooter(enabled: true, active: false, couldNotConnect: true)
            .hasPrefix("nutrx couldn't connect to iCloud"))
    }

    func testNotifications() {
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: true), "Noon check-in")
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: false), "Off")
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: false, weeklyRecap: true), "Recaps")
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: true, weeklyRecap: true), "Check-in and recap")
    }

    func testStreaks() {
        XCTAssertEqual(SettingsSummary.streaks(enabled: true), "On")
        XCTAssertEqual(SettingsSummary.streaks(enabled: false), "Off")
    }

    func testGroupsCountOnlyTheUsersOwn() {
        XCTAssertEqual(SettingsSummary.groups(userGroupCount: 0), "None")
        XCTAssertEqual(SettingsSummary.groups(userGroupCount: 2), "2")
    }

    func testProfileTitleFallsBackWhenThereIsNoName() {
        XCTAssertEqual(SettingsSummary.profileTitle(name: "Alex"), "Alex")
        XCTAssertEqual(SettingsSummary.profileTitle(name: "  Alex "), "Alex")
        XCTAssertEqual(SettingsSummary.profileTitle(name: ""), "Your profile")
        XCTAssertEqual(SettingsSummary.profileTitle(name: "   "), "Your profile")
    }
}
