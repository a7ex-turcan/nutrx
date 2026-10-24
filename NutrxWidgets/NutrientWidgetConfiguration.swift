import AppIntents
import WidgetKit

/// The one-nutrient widget's setting: which nutrient (the same picker as Siri and the controls).
struct NutrientWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Nutrient"
    static let description = IntentDescription("The nutrient to show.")

    @Parameter(title: "Nutrient")
    var nutrient: NutrientEntity?
}
