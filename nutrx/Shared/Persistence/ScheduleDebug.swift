#if DEBUG
import Foundation
import SwiftData

/// DEBUG only, until the Schedule sheet exists (#132 phase 3): gives nutrients a schedule at launch, by name, from today.
/// `xcrun simctl spawn <UDID> defaults write nutrx-labs.nutrx nutrx.debug.schedules -dict "Vitamin D" "days:1"`, then
/// relaunch. Kinds as stored: "days:2,4,6" (1 = Sunday), "cycle:1:1:20261023", "week:3", or "daily" to go back.
enum ScheduleDebug {
    static let key = "nutrx.debug.schedules"

    static func apply(to context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard let wanted = UserDefaults.standard.dictionary(forKey: key) as? [String: String], !wanted.isEmpty,
              let nutrients = try? context.fetch(FetchDescriptor<Nutrient>()) else { return }
        let today = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month, .day], from: today)
        let stamp = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        for nutrient in nutrients {
            // Read through the stored form, so the debug value is checked like a synced one.
            guard let kindText = wanted[nutrient.name],
                  let kind = NutrientSchedule.decode("\(stamp)=\(kindText)", calendar: calendar).pieces.first?.kind
            else { continue }
            nutrient.scheduleRaw = nutrient.schedule(calendar: calendar)
                .setting(kind, from: today, calendar: calendar).encode(calendar: calendar)
        }
        try? context.save()
    }
}
#endif
