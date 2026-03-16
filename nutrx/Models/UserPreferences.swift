import Foundation
import SwiftData

@Model
final class UserPreferences {
    var dailyReminderEnabled: Bool = false
    var hasSeenNotificationBanner: Bool = false

    init(dailyReminderEnabled: Bool = false, hasSeenNotificationBanner: Bool = false) {
        self.dailyReminderEnabled = dailyReminderEnabled
        self.hasSeenNotificationBanner = hasSeenNotificationBanner
    }
}
