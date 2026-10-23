import Foundation
import SwiftData
import WidgetKit

/// One nutrient on the Watch list: today's total and its goal progress.
struct WatchNutrientItem: Identifiable {
    let nutrient: Nutrient
    let total: Double

    var id: PersistentIdentifier { nutrient.persistentModelID }

    /// Status, ring fraction and text — the same rules as the iPhone's Today (`GoalProgress`).
    var progress: GoalProgress { GoalProgress(nutrient: nutrient, current: total) }
}

/// What the confirmation screen shows after a + tap: the nutrient's new total and the amount just logged.
struct WatchLogConfirmation: Identifiable {
    let id = UUID()
    let item: WatchNutrientItem
    let amount: Double
    /// This tap met the goal — a success haptic instead of a click.
    let metGoal: Bool
}

@Observable
final class WatchTodayViewModel {
    struct GroupSection: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let items: [WatchNutrientItem]
    }

    private(set) var sections: [GroupSection] = []
    /// Any non-deleted nutrients, excluded today or not.
    private(set) var hasNutrients = false
    private(set) var hasCustomGroups = false
    /// Set after a + tap; the view shows it until it's cleared.
    var confirmation: WatchLogConfirmation?

    /// Goals met today, for the "3/6" header.
    var metCount: Int { sections.flatMap(\.items).filter { $0.progress.countsAsMet }.count }
    var totalCount: Int { sections.reduce(0) { $0 + $1.items.count } }

    func refresh(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isRemoved },
            sortBy: [SortDescriptor(\Nutrient.sortOrder)]
        )
        guard let fetched = try? context.fetch(nutrientDescriptor) else { return }
        // As on Today: a nutrient whose course has ended (#99), or that isn't due today (#132), isn't on the Watch.
        let nutrients = fetched.filter { $0.isDue(on: startOfDay) }
        // Any running at all: a day with every nutrient off (#132) reads "Nothing to track today", not "Add a nutrient".
        hasNutrients = fetched.contains { $0.isRunning(on: startOfDay) }

        // Fetch groups
        let groupDescriptor = FetchDescriptor<NutrientGroup>(sortBy: [SortDescriptor(\NutrientGroup.sortOrder)])
        let allGroups = (try? context.fetch(groupDescriptor)) ?? []
        let generalGroup = allGroups.first(where: { $0.isSystem })
        hasCustomGroups = allGroups.contains(where: { !$0.isSystem })

        // Fetch today's exclusions
        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []
        let excludedIDs = Set(exclusions.compactMap { $0.nutrient?.persistentModelID })

        // Fetch today's intake records
        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let records = (try? context.fetch(intakeDescriptor)) ?? []

        var totalsByID: [PersistentIdentifier: Double] = [:]
        for record in records {
            if let id = record.nutrient?.persistentModelID {
                totalsByID[id, default: 0] += record.amount
            }
        }

        let activeNutrients = nutrients.filter { !excludedIDs.contains($0.persistentModelID) }

        var result: [GroupSection] = []
        for group in allGroups {
            let groupNutrients = activeNutrients
                .filter { ($0.group ?? generalGroup)?.persistentModelID == group.persistentModelID }
                .sorted {
                    if $0.groupSortOrder != $1.groupSortOrder {
                        return $0.groupSortOrder < $1.groupSortOrder
                    }
                    return $0.sortOrder < $1.sortOrder
                }

            guard !groupNutrients.isEmpty else { continue }

            let items = groupNutrients.map { nutrient in
                WatchNutrientItem(nutrient: nutrient, total: max(0, totalsByID[nutrient.persistentModelID] ?? 0))
            }
            result.append(GroupSection(id: group.persistentModelID, name: group.name, items: items))
        }

        sections = result
    }

    /// Logs one step and sets `confirmation` to the nutrient's new total.
    func increment(_ nutrient: Nutrient, context: ModelContext) {
        let wasMet = item(for: nutrient)?.progress.countsAsMet ?? false
        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()
        updateTotal(for: nutrient, delta: nutrient.step)
        WidgetCenter.shared.reloadAllTimelines()

        if let item = item(for: nutrient) {
            confirmation = WatchLogConfirmation(item: item, amount: nutrient.step,
                                                metGoal: !wasMet && item.progress.countsAsMet)
        }
    }

    private func item(for nutrient: Nutrient) -> WatchNutrientItem? {
        sections.lazy.flatMap(\.items).first { $0.id == nutrient.persistentModelID }
    }

    private func updateTotal(for nutrient: Nutrient, delta: Double) {
        let id = nutrient.persistentModelID
        for sIdx in sections.indices {
            if let nIdx = sections[sIdx].items.firstIndex(where: { $0.id == id }) {
                let old = sections[sIdx].items[nIdx]
                var items = sections[sIdx].items
                items[nIdx] = WatchNutrientItem(nutrient: old.nutrient, total: max(0, old.total + delta))
                sections[sIdx] = GroupSection(id: sections[sIdx].id, name: sections[sIdx].name, items: items)
                return
            }
        }
    }
}
