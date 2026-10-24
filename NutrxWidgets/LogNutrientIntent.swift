import AppIntents
import SwiftData
import WidgetKit
import os.log

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "LogNutrientIntent")

struct LogNutrientIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Nutrient"
    static var description: IntentDescription = "Log one step of a nutrient"
    /// The widget's + button only. It takes a raw id, so it stays out of Shortcuts; Siri and Shortcuts use
    /// `LogNutrientShortcutIntent` in the app.
    static var isDiscoverable: Bool = false

    @Parameter(title: "Nutrient ID")
    var nutrientID: String

    init() {}

    init(nutrientID: String) {
        self.nutrientID = nutrientID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: nutrientID) { Self.logStep(nutrientID: id) }
        return .result()
    }

    /// One step of a nutrient, as a + tap on Today: the widget's + and the Log nutrient control (#138). In the widget
    /// extension it uses the extension-safe container; the app (an intent run there) uses its own.
    @MainActor
    static func logStep(nutrientID: UUID) {
        let container: ModelContainer
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            do {
                container = try ModelContainerFactory.createForExtension()
            } catch {
                logger.error(
                    "Widget log tap couldn't open the shared store: \(error.localizedDescription, privacy: .public)")
                return
            }
        } else {
            container = ModelContainerFactory.create()
        }
        let context = container.mainContext

        let descriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isRemoved }
        )
        let nutrients = (try? context.fetch(descriptor)) ?? []
        guard let nutrient = nutrients.first(where: { $0.id == nutrientID }) else {
            logger.error("Widget log tap found no nutrient \(nutrientID, privacy: .public)")
            return
        }

        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()

        WidgetReload.all()
    }
}
