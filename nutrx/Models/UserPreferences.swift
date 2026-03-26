import Foundation
import SwiftData

@Model
final class UserPreferences {
    var dailyReminderEnabled: Bool = false
    var hasSeenNotificationBanner: Bool = false
    var streaksEnabled: Bool = true

    init(dailyReminderEnabled: Bool = false, hasSeenNotificationBanner: Bool = false, streaksEnabled: Bool = true) {
        self.dailyReminderEnabled = dailyReminderEnabled
        self.hasSeenNotificationBanner = hasSeenNotificationBanner
        self.streaksEnabled = streaksEnabled
    }
}
