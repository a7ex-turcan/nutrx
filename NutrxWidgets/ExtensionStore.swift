import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "ExtensionStore")

/// The shared store as the Pro controls and widgets (#138) see it: read-only for what they show, writable for a log
/// tap (opened per tap, as `LogNutrientIntent` does). Never `create()` in an extension (CLAUDE.md, iCloud Sync).
@MainActor
enum ExtensionStore {
    static func writable() -> ModelContainer? {
        do {
            return try ModelContainerFactory.createForExtension()
        } catch {
            logger.error("Couldn't open the shared store to log: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func stack(id: UUID, in context: ModelContext? = nil) -> LogStack? {
        guard let context = context ?? readOnlyContext() else { return nil }
        return (try? context.fetch(FetchDescriptor<LogStack>()))?.first { $0.id == id }
    }

    /// Removed ones included, so a control or widget can say so.
    static func nutrient(id: UUID) -> Nutrient? {
        guard let context = readOnlyContext() else { return nil }
        return (try? context.fetch(FetchDescriptor<Nutrient>(predicate: #Predicate { $0.id == id })))?.first
    }

    /// What's logged of `nutrient` on `now`'s day, from the context it was read in.
    static func todayTotal(of nutrient: Nutrient, now: Date = .now, calendar: Calendar = .current) -> Double {
        guard let context = nutrient.modelContext else { return 0 }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let id = nutrient.id
        let descriptor = FetchDescriptor<IntakeRecord>(predicate: #Predicate {
            $0.nutrient?.id == id && $0.date >= start && $0.date < end
        })
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.amount }
    }

    private static func readOnlyContext() -> ModelContext? {
        (try? ModelContainerFactory.createForExtension(allowsSave: false)).map { ModelContext($0) }
    }
}
