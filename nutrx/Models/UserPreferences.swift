import Foundation
import SwiftData

@Model
final class UserPreferences {
    var dailyReminderEnabled: Bool = false
    var hasSeenNotificationBanner: Bool = false
    var streaksEnabled: Bool = true
    /// Legacy: synced to every device and never read for syncing. The per-device choice is `ICloudSync` (#113),
    /// which reads this once, on the first launch that has it.
    var iCloudSyncEnabled: Bool = true
    var hasSeenSyncRestoredBanner: Bool = false
    var hasSeenSyncEnabledBanner: Bool = false
    var lastReviewRequestedVersion: String? = nil
    var lastReviewRequestedDate: Date? = nil
    var hasSeenAnalyticsBanner: Bool = false

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
