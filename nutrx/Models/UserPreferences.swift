import Foundation
import SwiftData

@Model
final class UserPreferences {
    var dailyReminderEnabled: Bool

    init(dailyReminderEnabled: Bool = false) {
        self.dailyReminderEnabled = dailyReminderEnabled
    }
}
