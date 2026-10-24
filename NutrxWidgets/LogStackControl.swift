import AppIntents
import os.log
import SwiftData
import SwiftUI
import WidgetKit

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "LogStackControl")

// The Log stack control (nutrx Pro, #138, docs/pro/WIDGETS.md §2), in Control Center, on the Lock Screen and on the
// Action button, set up with a stack when added. A control's template can't branch on its action, so one intent
// decides when tapped: log, or open the app. What it shows and does comes from `ControlText`.

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
        let logStack = ExtensionStore.stack(id: stack.id, in: context)
        if logStack == nil { logger.error("Log stack control found no stack \(stack.id, privacy: .public)") }
        switch ControlText.tap(ControlText.state(of: logStack, isPro: true)) {
        case .open(let screen):
            return .result(opensIntent: OpenNutrxIntent(screen))
        case .nothing:
            return .result()
        case .log:
            if let logStack, !StackLogging.log(logStack, context: context).records.isEmpty {
                WidgetReload.all()
            }
            return .result()
        }
    }
}
