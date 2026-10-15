import XCTest
@testable import nutrx

/// DESIGN.md §5.9 — the values on the Settings rows and the profile card title.
final class SettingsSummaryTests: XCTestCase {

    func testICloud() {
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, syncEnabled: true), "On")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: true, syncEnabled: false), "Off")
        XCTAssertEqual(SettingsSummary.iCloud(hasAccount: false, syncEnabled: true), "No account")
    }

    func testNotifications() {
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: true), "Noon check-in")
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: false), "Off")
        XCTAssertEqual(SettingsSummary.notifications(dailyReminderEnabled: false, weeklyRecap: true), "Weekly recap")
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
