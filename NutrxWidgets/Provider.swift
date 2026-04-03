import WidgetKit
import SwiftData

struct NutrxTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutrxWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NutrxWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutrxWidgetEntry>) -> Void) {
        let entry = fetchEntry()
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    @MainActor
    private func fetchEntry() -> NutrxWidgetEntry {
        let container: ModelContainer
        do {
            let schema = Schema([
                UserProfile.self,
                Nutrient.self,
                IntakeRecord.self,
                Exclusion.self,
                UserPreferences.self,
                NutrientReminder.self,
                NutrientGroup.self,
            ])
            let storeURL = ModelContainerFactory.sharedStoreURL()
            let configuration = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            return NutrxWidgetEntry(date: .now, nutrients: [], isPlaceholder: false, currentStreak: 0, streaksEnabled: false)
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
                return a.groupSortOrder < b.groupSortOrder
            }

        let snapshots = activeNutrients.map { n in
            NutrientSnapshot(
                id: n.id.uuidString,
                name: n.name,
                unit: n.unit,
                current: max(0, totals[n.persistentModelID] ?? 0),
                target: n.dailyTarget,
                step: n.step,
                goalTypeRaw: n.goalTypeRaw,
                upperBound: n.upperBound
            )
        }

        return NutrxWidgetEntry(date: .now, nutrients: snapshots, isPlaceholder: false, currentStreak: streakResult.current, streaksEnabled: streaksEnabled)
    }
}
