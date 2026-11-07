import Foundation
import SwiftData

/// Dose plans without Pro (#135, docs/pro/DOSE-PLANS.md §6), run after each entitlement check (never on an unknown
/// one, such as a cold background launch).
/// - **With Pro:** each moving or held plan's marker (`Nutrient.dosePlanSeenWithPro`) records today, at most once a
///   day, and a held plan resumes where it held: its remaining steps, and a stopping plan's course end, move later.
/// - **Without:** a moving plan holds from today, but only when its marker is more than a day old, so two devices that
///   disagree about Pro can't hold and resume it back and forth. A held plan that stops has its course end lifted.
///
/// The rules are `NutrientDosePlan`'s (`canHold`, `holding`, `resuming`); this writes them. Tested in
/// `DosePlanHoldTests`.
enum DosePlanHold {
    /// - Returns: whether any nutrient changed.
    @discardableResult
    static func sync(isPro: Bool, context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.dosePlanRaw != "" && !$0.isRemoved })
        let nutrients = (try? context.fetch(descriptor)) ?? []
        let today = calendar.startOfDay(for: now)
        let todayText = StoredDay.string(today, calendar: calendar)
        var changed = false

        for nutrient in nutrients {
            let plan = nutrient.dosePlan(calendar: calendar)
            guard let current = plan.plan else { continue }
            let isHeld = current.heldFrom != nil
            if isPro {
                // The marker only matters while the plan could hold: a finished or kept plan never does.
                if (isHeld || plan.isMoving(on: today, calendar: calendar)), nutrient.dosePlanSeenWithPro != todayText {
                    nutrient.dosePlanSeenWithPro = todayText
                    changed = true
                }
                guard isHeld else { continue }
                let resumed = plan.resuming(today: today, calendar: calendar)
                nutrient.dosePlanRaw = resumed.encode(calendar: calendar)
                if let stopDay = resumed.stopDay(calendar: calendar) {
                    nutrient.setCourse(endDate: stopDay, now: now, calendar: calendar)
                }
                changed = true
            } else {
                let seen = StoredDay.date(Substring(nutrient.dosePlanSeenWithPro), calendar: calendar)
                guard plan.canHold(on: today, seenWithPro: seen, calendar: calendar) else { continue }
                // Lifted before holding: a held plan has no stop day of its own.
                if let stopDay = plan.stopDay(calendar: calendar), let endDate = nutrient.endDate,
                   calendar.startOfDay(for: endDate) == stopDay {
                    nutrient.setCourse(endDate: nil, now: now, calendar: calendar)
                }
                nutrient.dosePlanRaw = plan.holding(from: today, calendar: calendar).encode(calendar: calendar)
                changed = true
            }
        }

        if changed {
            try? context.save()
            WidgetReload.all()
        }
        return changed
    }
}
