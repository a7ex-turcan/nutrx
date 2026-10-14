import AppIntents
import SwiftData
import WidgetKit

/// "Log Nutrient" for Siri and the Shortcuts app: a nutrient picked by name and an optional amount (one step when
/// it's left empty). Runs in the app's process, on the app's own store. The widget's + button keeps using
/// `LogNutrientIntent`, which takes a raw id and is hidden from Shortcuts.
struct LogNutrientShortcutIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Nutrient"
    static let description = IntentDescription(
        "Log an amount of one of your nutrients in nutrx. Leave the amount empty to log one step.")

    @Parameter(title: "Nutrient")
    var nutrient: NutrientEntity

    @Parameter(title: "Amount", description: "In the nutrient's unit. Leave empty to log one step.")
    var amount: Double?

    /// "Log 0.5 of Water", or "Log one step of Water" with Amount under the action's expanded options: a parameter
    /// that's in neither place can't be set in the Shortcuts editor at all.
    static var parameterSummary: some ParameterSummary {
        When(\.$amount, .hasAnyValue) {
            Summary("Log \(\.$amount) of \(\.$nutrient)")
        } otherwise: {
            Summary("Log one step of \(\.$nutrient)") {
                \.$amount
            }
        }
    }

    @Dependency private var modelContainer: ModelContainer

    init() {}

    init(nutrient: NutrientEntity, amount: Double? = nil) {
        self.nutrient = nutrient
        self.amount = amount
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = modelContainer.mainContext
        let logged = try NutrientShortcutLogging.log(nutrientID: nutrient.id, amount: amount, context: context)
        // The same follow-ups as a + tap on Today.
        NotificationService.refreshDailyReminder(context: context)
        NotificationService.refreshAllNutrientReminders(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "\(logged.confirmation)")
    }
}

/// The logging behind `LogNutrientShortcutIntent`, kept apart from App Intents so it can be tested.
enum NutrientShortcutLogging {
    struct Logged: Equatable {
        let amount: Double
        /// "Logged 1,000 IU of Vitamin D. 3,000 of 4,000 IU today."
        let confirmation: String
    }

    enum Failure: Error, Equatable, CustomLocalizedStringResourceConvertible {
        case nutrientNotFound
        case amountNotPositive

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .nutrientNotFound: "That nutrient isn't in nutrx anymore."
            case .amountNotPositive: "Enter an amount above zero."
            }
        }
    }

    /// Inserts one intake record (the given amount, or one step) and saves.
    @MainActor
    static func log(nutrientID: UUID, amount: Double?, context: ModelContext, now: Date = .now,
                    locale: Locale = .current) throws -> Logged {
        guard let nutrient = NutrientEntityQuery.activeNutrients(in: context).first(where: { $0.id == nutrientID })
        else { throw Failure.nutrientNotFound }
        let logAmount = amount ?? nutrient.step
        guard logAmount > 0 else { throw Failure.amountNotPositive }

        context.insert(IntakeRecord(nutrient: nutrient, amount: logAmount, date: now))
        try context.save()

        let progress = GoalProgress(nutrient: nutrient, current: todayTotal(of: nutrient, now: now))
        let unitSuffix = nutrient.unit.isEmpty ? "" : " \(nutrient.unit)"
        let confirmation = "Logged \(logAmount.formattedAmount(locale: locale))\(unitSuffix) of \(nutrient.name). "
            + "\(progress.progressText(locale: locale)) today."
        return Logged(amount: logAmount, confirmation: confirmation)
    }

    /// The sum of the nutrient's records on `now`'s calendar day, floored at 0 like everywhere else.
    static func todayTotal(of nutrient: Nutrient, now: Date) -> Double {
        let calendar = Calendar.current
        let total = (nutrient.intakeRecords ?? [])
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amount }
        return max(total, 0)
    }
}
