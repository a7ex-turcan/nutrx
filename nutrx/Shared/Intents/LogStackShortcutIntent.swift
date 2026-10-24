import AppIntents
import SwiftData

/// "Log Stack" for Siri and the Shortcuts app: logs every nutrient in a stack at its amount, the same as Log on
/// Today's stack card. Runs in the app's process, on the app's own store.
struct LogStackShortcutIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Stack"
    static let description = IntentDescription(
        "Log every nutrient in one of your nutrx stacks at its amount.")

    @Parameter(title: "Stack")
    var stack: StackEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Log the \(\.$stack) stack")
    }

    @Dependency private var modelContainer: ModelContainer

    init() {}

    init(stack: StackEntity) {
        self.stack = stack
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = modelContainer.mainContext
        let confirmation = try StackShortcutLogging.log(stackID: stack.id, context: context)
        // The same follow-ups as Log on Today's stack card.
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetReload.all()
        NotificationCenter.default.post(name: .intakeLoggedByShortcut, object: nil)
        return .result(dialog: "\(confirmation)")
    }
}

/// The logging behind `LogStackShortcutIntent`, kept apart from App Intents so it can be tested.
enum StackShortcutLogging {
    enum Failure: Error, Equatable, CustomLocalizedStringResourceConvertible {
        case stackNotFound
        case nothingToLog

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .stackNotFound: "That stack isn't in nutrx anymore."
            case .nothingToLog: "That stack has no nutrients yet. Add some in the Stacks tab."
            }
        }
    }

    /// Logs the stack through `StackLogging.log` and returns what Siri says:
    /// "Logged Morning: 2,000 IU Vitamin D, 1,000 mg Omega-3 and 400 mg Magnesium."
    @MainActor
    static func log(stackID: UUID, context: ModelContext, now: Date = .now, locale: Locale = .current) throws -> String {
        guard let stack = StackEntityQuery.stacks(in: context).first(where: { $0.id == stackID })
        else { throw Failure.stackNotFound }
        let logged = StackLogging.log(stack, context: context, now: now)
        guard !logged.records.isEmpty else { throw Failure.nothingToLog }

        let parts = logged.records.compactMap { record -> String? in
            guard let nutrient = record.nutrient else { return nil }
            let unitSuffix = nutrient.unit.isEmpty ? "" : " \(nutrient.unit)"
            return "\(record.amount.formattedAmount(locale: locale))\(unitSuffix) \(nutrient.name)"
        }
        return "Logged \(stack.name): \(parts.formatted(.list(type: .and).locale(locale)))."
    }

    /// Siri's "Log my <stack> stack" phrases use the stacks' names: call after a stack is created, renamed or deleted.
    static func stacksChanged() {
        NutrxShortcuts.updateAppShortcutParameters()
        WidgetReload.all()  // the Log stack control shows the stack's name
    }

    /// What to say to Siri for a stack — the first "Log Stack" phrase in `NutrxShortcuts`, with the stack's name.
    static func siriPhrase(for stackName: String) -> String {
        "Log my \(stackName) stack with nutrx"
    }
}
