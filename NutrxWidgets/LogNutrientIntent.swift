import AppIntents
import SwiftData
import WidgetKit
import os.log

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "LogNutrientIntent")

struct LogNutrientIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Nutrient"
    static var description: IntentDescription = "Log one step of a nutrient"

    @Parameter(title: "Nutrient ID")
    var nutrientID: String

    init() {}

    init(nutrientID: String) {
        self.nutrientID = nutrientID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Widget buttons run this in the widget extension, which must use the extension-safe container.
        let container: ModelContainer
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            do {
                container = try ModelContainerFactory.createForExtension()
            } catch {
                logger.error("Widget log tap couldn't open the shared store: \(error.localizedDescription)")
                return .result()
            }
        } else {
            container = ModelContainerFactory.create()
        }
        let context = container.mainContext

        guard let nutrientUUID = UUID(uuidString: nutrientID) else { return .result() }

        let descriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let nutrients = (try? context.fetch(descriptor)) ?? []
        guard let nutrient = nutrients.first(where: { $0.id == nutrientUUID }) else {
            logger.error("Widget log tap found no nutrient \(nutrientID)")
            return .result()
        }

        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
