import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "ExtensionStore")

/// The shared store as the Pro controls (#138) see it: read-only for what they show, writable for a log tap (opened
/// per tap, as `LogNutrientIntent` does). Never `create()` in an extension (CLAUDE.md, iCloud Sync).
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

    /// Removed ones included, so a control can say so.
    static func nutrient(id: UUID) -> Nutrient? {
        guard let context = readOnlyContext() else { return nil }
        return (try? context.fetch(FetchDescriptor<Nutrient>(predicate: #Predicate { $0.id == id })))?.first
    }

    private static func readOnlyContext() -> ModelContext? {
        (try? ModelContainerFactory.createForExtension(allowsSave: false)).map { ModelContext($0) }
    }
}
