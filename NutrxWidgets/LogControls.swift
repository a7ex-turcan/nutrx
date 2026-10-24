import AppIntents
import os.log
import SwiftData
import SwiftUI
import WidgetKit

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "LogControls")

// The Control Center (and Lock Screen, Action button) controls (nutrx Pro, #138, docs/pro/WIDGETS.md §2): Log stack
// and Log nutrient, each set up with a stack or a nutrient when added. Free users get the same control with
// "nutrx Pro", which opens the paywall. A control's template can't branch on its action, so each has one intent
// that decides when tapped: log, or open the app (the paywall when free, the app when nothing is chosen yet).
// What they show comes from `ControlText`.

// MARK: - Log stack

struct NutrxLogStackControl: ControlWidget {
    static let kind = "NutrxLogStackControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: StackControlProvider()) { value in
            ControlWidgetButton(action: LogStackControlIntent(stack: value.stack)) {
                if let name = value.name {
                    Label(name, systemImage: ControlText.symbol(value.state))
                    Text(ControlText.text(value.state))
                } else {
                    Label("Choose a stack", systemImage: ControlText.symbol(.ready))
                }
            }
        }
        .displayName("Log stack")
        .description("Logs one of your stacks, as Log on Today does.")
        .promptsForUserConfiguration()
    }
}

struct StackControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Log stack"

    @Parameter(title: "Stack")
    var stack: StackEntity?
}

struct StackControlValue {
    let stack: StackEntity?
    /// The stack's current name; nil until one is chosen.
    let name: String?
    let state: ControlText.StackState
}

struct StackControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: StackControlConfiguration) -> StackControlValue {
        StackControlValue(stack: configuration.stack, name: configuration.stack?.name, state: .ready)
    }

    func currentValue(configuration: StackControlConfiguration) async throws -> StackControlValue {
        guard let stack = configuration.stack else { return StackControlValue(stack: nil, name: nil, state: .ready) }
        let isPro = await ProEntitlement.current() != nil
        return await MainActor.run {
            let logStack = ExtensionStore.stack(id: stack.id)
            let state = ControlText.state(of: logStack, isPro: isPro)
            return StackControlValue(stack: stack, name: logStack?.name ?? stack.name, state: state)
        }
    }
}

/// The Log stack control's tap, in the widget extension: the same records as Log on Today (`StackLogging.log`).
struct LogStackControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Stack"
    /// The control's only. Siri and Shortcuts use `LogStackShortcutIntent` in the app.
    static let isDiscoverable = false

    @Parameter(title: "Stack")
    var stack: StackEntity?

    init() {}

    init(stack: StackEntity?) {
        self.stack = stack
    }

    /// `OpensIntent` in the signature, here and in `LogNutrientControlIntent`: without it iOS drops the returned
    /// intent ("Did not declare OpensIntent but provided one") and a free tap opened nothing.
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard await ProEntitlement.current() != nil else { return .result(opensIntent: OpenNutrxIntent(.pro)) }
        guard let stack, let container = ExtensionStore.writable() else {
            return .result(opensIntent: OpenNutrxIntent(.today))
        }
        let context = container.mainContext
        guard let logStack = ExtensionStore.stack(id: stack.id, in: context) else {
            logger.error("Log stack control found no stack \(stack.id, privacy: .public)")
            return .result(opensIntent: OpenNutrxIntent(.today))
        }
        // Nothing due today logs nothing, as on Today; the control says so.
        if !StackLogging.log(logStack, context: context).records.isEmpty {
            WidgetReload.all()
        }
        return .result()
    }
}

// MARK: - Log nutrient

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

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard await ProEntitlement.current() != nil else { return .result(opensIntent: OpenNutrxIntent(.pro)) }
        guard let nutrient else { return .result(opensIntent: OpenNutrxIntent(.nutrients)) }
        // Removed or its course ended: nothing to log, so open My Nutrients (an ended course is under Finished).
        guard ExtensionStore.nutrient(id: nutrient.id)?.isRunning() == true else {
            return .result(opensIntent: OpenNutrxIntent(.nutrients))
        }
        LogNutrientIntent.logStep(nutrientID: nutrient.id)
        return .result()
    }
}

// MARK: - The store

/// The shared store as the controls see it: read-only for what they show, writable for a log tap (opened per tap, as
/// `LogNutrientIntent` does). Never `create()` in an extension (CLAUDE.md, iCloud Sync).
@MainActor
enum ExtensionStore {
    static func writable() -> ModelContainer? {
        do {
            return try ModelContainerFactory.createForExtension()
        } catch {
            logger.error("Control couldn't open the shared store: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func stack(id: UUID, in context: ModelContext? = nil) -> LogStack? {
        guard let context = context ?? readOnlyContext() else { return nil }
        return (try? context.fetch(FetchDescriptor<LogStack>()))?.first { $0.id == id }
    }

    /// Removed ones included, so the control can say so.
    static func nutrient(id: UUID) -> Nutrient? {
        guard let context = readOnlyContext() else { return nil }
        return (try? context.fetch(FetchDescriptor<Nutrient>(predicate: #Predicate { $0.id == id })))?.first
    }

    private static func readOnlyContext() -> ModelContext? {
        (try? ModelContainerFactory.createForExtension(allowsSave: false)).map { ModelContext($0) }
    }
}
