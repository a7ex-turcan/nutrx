import Foundation
import SwiftData

@Model
final class UserPreferences {
    var dailyReminderEnabled: Bool = false
    var hasSeenNotificationBanner: Bool = false
    var streaksEnabled: Bool = true
    var iCloudSyncEnabled: Bool = true
    var hasSeenSyncRestoredBanner: Bool = false
    var hasSeenSyncEnabledBanner: Bool = false

    init(
        dailyReminderEnabled: Bool = false,
        hasSeenNotificationBanner: Bool = false,
        streaksEnabled: Bool = true,
        iCloudSyncEnabled: Bool = true,
        hasSeenSyncRestoredBanner: Bool = false,
        hasSeenSyncEnabledBanner: Bool = false
    ) {
        self.dailyReminderEnabled = dailyReminderEnabled
        self.hasSeenNotificationBanner = hasSeenNotificationBanner
        self.streaksEnabled = streaksEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.hasSeenSyncRestoredBanner = hasSeenSyncRestoredBanner
        self.hasSeenSyncEnabledBanner = hasSeenSyncEnabledBanner
    }
}
