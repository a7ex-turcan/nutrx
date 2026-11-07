#if DEBUG
import Foundation
import SwiftData

/// DEBUG only, until the Dose plan sheet exists (#135 phase 3): gives nutrients a dose plan at launch, by name,
/// starting today. `xcrun simctl spawn <UDID> defaults write nutrx-labs.nutrx nutrx.debug.dosePlans -dict
/// "Magnesium" "200x7,400x14|keep"`, then relaunch. Steps as stored (goal "x" days, a range "120~160x7"), then
/// "keep" or "stop"; "none" removes the plan. A value starting "h=" or "p=" is the whole stored form instead, to start
/// in the past. Applied once per value, so a relaunch with the same one doesn't start the plan over.
enum DosePlanDebug {
    static let key = "nutrx.debug.dosePlans"
    private static let appliedKey = "nutrx.debug.dosePlansApplied"

    static func apply(to context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard let wanted = UserDefaults.standard.dictionary(forKey: key) as? [String: String], !wanted.isEmpty,
              let nutrients = try? context.fetch(FetchDescriptor<Nutrient>()) else { return }
        var applied = UserDefaults.standard.dictionary(forKey: appliedKey) as? [String: String] ?? [:]
        for nutrient in nutrients {
            guard let value = wanted[nutrient.name], applied[nutrient.name] != value else { continue }
            applied[nutrient.name] = value
            if value.hasPrefix("h=") || value.hasPrefix("p=") {
                nutrient.dosePlanRaw = NutrientDosePlan.decode(value, calendar: calendar).encode(calendar: calendar)
                continue
            }
            let plan = nutrient.dosePlan(calendar: calendar)
            if value == "none" {
                let removed = plan.removing(today: now, calendar: calendar)
                if let base = removed.newBase {
                    nutrient.dailyTarget = base.target
                    nutrient.upperBound = base.upperBound
                }
                nutrient.dosePlanRaw = removed.plan.encode(calendar: calendar)
                continue
            }
            // Read through the stored form, so the debug value is checked like a synced one.
            let halves = value.split(separator: "|", maxSplits: 1)
            guard halves.count == 2, let end = NutrientDosePlan.End(rawValue: String(halves[1])),
                  let steps = NutrientDosePlan.decode("p=20000101,20000101,keep|\(halves[0])", calendar: calendar)
                    .plan?.steps else { continue }
            let created = plan.creating(steps: steps, end: end, start: now, base: nutrient.baseGoal, today: now,
                                        calendar: calendar)
            nutrient.dosePlanRaw = created.encode(calendar: calendar)
            // Only a plan that stops sets the course's end; one that keeps leaves Duration alone (§5).
            if end == .stop {
                nutrient.setCourse(endDate: created.stopDay(calendar: calendar), now: now, calendar: calendar)
            }
        }
        UserDefaults.standard.set(applied, forKey: appliedKey)
        try? context.save()
    }
}
#endif
