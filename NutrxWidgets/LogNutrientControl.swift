import AppIntents
import SwiftUI
import WidgetKit

// The Log nutrient control (nutrx Pro, #138, docs/pro/WIDGETS.md §2): one step of a nutrient chosen when it's added,
// as the widget's + logs. Like Log stack, one intent decides when tapped; what it shows and does comes from
// `ControlText`.

struct NutrxLogNutrientControl: ControlWidget {
    static let kind = "NutrxLogNutrientControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: NutrientControlProvider()) { value in
            ControlWidgetButton(action: LogNutrientControlIntent(nutrient: value.nutrient)) {
                if let name = value.name {
                    Label(name, systemImage: value.symbolName)
                    Text(value.text)
                } else {
                    Label("Choose a nutrient", systemImage: "leaf")
                }
            }
        }
        .displayName("Log nutrient")
        .description("Logs one step of a nutrient, as + on Today does.")
        .promptsForUserConfiguration()
    }
}

struct NutrientControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Log nutrient"

    @Parameter(title: "Nutrient")
    var nutrient: NutrientEntity?
}

struct NutrientControlValue {
    let nutrient: NutrientEntity?
    /// The nutrient's current name; nil until one is chosen.
    let name: String?
    let symbolName: String
    let text: String
}

struct NutrientControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: NutrientControlConfiguration) -> NutrientControlValue {
        let nutrient = configuration.nutrient
        return NutrientControlValue(
            nutrient: nutrient, name: nutrient?.name, symbolName: "leaf",
            text: nutrient.map { ControlText.text(.ready(step: $0.step, unit: $0.unit)) } ?? "")
    }

    func currentValue(configuration: NutrientControlConfiguration) async throws -> NutrientControlValue {
        guard let nutrient = configuration.nutrient else {
            return NutrientControlValue(nutrient: nil, name: nil, symbolName: "leaf", text: "")
        }
        let isPro = await ProEntitlement.current() != nil
        return await MainActor.run {
            let stored = ExtensionStore.nutrient(id: nutrient.id)
            let state = ControlText.state(of: stored, isPro: isPro)
            return NutrientControlValue(nutrient: nutrient, name: stored?.name ?? nutrient.name,
                                        symbolName: stored?.symbolName ?? "leaf", text: ControlText.text(state))
        }
    }
}

/// The Log nutrient control's tap: one step, as the widget's + (`LogNutrientIntent.logStep`).
struct LogNutrientControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Nutrient"
    /// The control's only. Siri and Shortcuts use `LogNutrientShortcutIntent` in the app.
    static let isDiscoverable = false

    @Parameter(title: "Nutrient")
    var nutrient: NutrientEntity?

    init() {}

    init(nutrient: NutrientEntity?) {
        self.nutrient = nutrient
    }

    /// `OpensIntent`: see `LogStackControlIntent.perform()`.
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let isPro = await ProEntitlement.current() != nil
        guard let nutrient else { return .result(opensIntent: OpenNutrxIntent(isPro ? .nutrients : .pro)) }
        switch ControlText.tap(ControlText.state(of: ExtensionStore.nutrient(id: nutrient.id), isPro: isPro)) {
        case .open(let screen):
            return .result(opensIntent: OpenNutrxIntent(screen))
        case .nothing:
            return .result()
        case .log:
            LogNutrientIntent.logStep(nutrientID: nutrient.id)
            return .result()
        }
    }
}
