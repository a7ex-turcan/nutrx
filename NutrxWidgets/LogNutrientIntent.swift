import AppIntents
import SwiftData
import WidgetKit

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
        let container = ModelContainerFactory.create()
        let context = container.mainContext

        guard let nutrientUUID = UUID(uuidString: nutrientID) else { return .result() }

        let descriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let nutrients = (try? context.fetch(descriptor)) ?? []
        guard let nutrient = nutrients.first(where: { $0.id == nutrientUUID }) else {
            return .result()
        }

        let record = IntakeRecord(nutrient: nutrient, amount: nutrient.step)
        context.insert(record)
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
