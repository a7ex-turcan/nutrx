import WidgetKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "WidgetTimeline")

struct NutrxTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutrxWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NutrxWidgetEntry) -> Void) {
        guard !context.isPreview else { return completion(.placeholder) }
        Task { @MainActor in
            completion(fetchEntry(includeSupply: await ProEntitlement.current() != nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutrxWidgetEntry>) -> Void) {
        Task { @MainActor in
            // Supply is Pro: StoreKit answers in the extension too (nothing is cached from the app).
            let entry = fetchEntry(includeSupply: await ProEntitlement.current() != nil)
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            )
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    @MainActor
    private func fetchEntry(includeSupply: Bool = false) -> NutrxWidgetEntry {
        // The extension-safe container (no CloudKit), read-only: the timeline never writes.
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.createForExtension(allowsSave: false)
        } catch {
            logger.error(
                "Widget timeline couldn't open the shared store: \(error.localizedDescription, privacy: .public)")
            return .empty
        }

        let context = container.mainContext

        // Fetch streak + preferences
        let prefsDescriptor = FetchDescriptor<UserPreferences>()
        let prefs = (try? context.fetch(prefsDescriptor))?.first
        let streaksEnabled = prefs?.streaksEnabled ?? true
        let streakResult = streaksEnabled ? StreakService.compute(context: context) : StreakResult(current: 0, best: 0)

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch groups sorted
        let groupDescriptor = FetchDescriptor<NutrientGroup>(
            sortBy: [SortDescriptor(\NutrientGroup.sortOrder)]
        )
        let allGroups = (try? context.fetch(groupDescriptor)) ?? []
        let generalGroup = allGroups.first(where: { $0.isSystem })

        // Fetch nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let nutrients = (try? context.fetch(nutrientDescriptor)) ?? []

        // Fetch today's exclusions
        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []
        let excludedIDs = Set(exclusions.compactMap { $0.nutrient?.persistentModelID })

        // Fetch today's intake
        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let records = (try? context.fetch(intakeDescriptor)) ?? []
        var totals: [PersistentIdentifier: Double] = [:]
        for r in records {
            if let id = r.nutrient?.persistentModelID {
                totals[id, default: 0] += r.amount
            }
        }

        // Sort nutrients by group order, then groupSortOrder
        let activeNutrients = nutrients
            .filter { !excludedIDs.contains($0.persistentModelID) }
            .sorted { a, b in
                let aGroupOrder = (a.group ?? generalGroup)?.sortOrder ?? Int.max
                let bGroupOrder = (b.group ?? generalGroup)?.sortOrder ?? Int.max
                if aGroupOrder != bGroupOrder { return aGroupOrder < bGroupOrder }
                if a.groupSortOrder != b.groupSortOrder { return a.groupSortOrder < b.groupSortOrder }
                return a.sortOrder < b.sortOrder  // same tiebreak as Today
            }

        let snapshots = activeNutrients.map { n in
            NutrientSnapshot(
                id: n.id.uuidString,
                name: n.name,
                unit: n.unit,
                current: max(0, totals[n.persistentModelID] ?? 0),
                target: n.dailyTarget,
                step: n.step,
                goalType: n.goalType,
                upperBound: n.upperBound,
                tint: n.tint,
                symbolName: n.symbolName
            )
        }

        var runningLow: NutrxWidgetEntry.RunningLow?
        if includeSupply {
            let statuses = activeNutrients.compactMap { n in n.supplyStatus().map { (id: n.name, status: $0) } }
            if let soonest = SupplySchedule.soonest(statuses) {
                runningLow = .init(name: soonest.id, daysLeft: soonest.status.daysLeft ?? 0,
                                   isOut: soonest.status.level == .out)
            }
        }

        return NutrxWidgetEntry(date: .now, nutrients: snapshots, isPlaceholder: false, currentStreak: streakResult.current,
                                streaksEnabled: streaksEnabled, runningLow: runningLow)
    }
}
