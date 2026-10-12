import SwiftData
import XCTest
@testable import nutrx

/// Day score and next reminder as Today computes them from the store.
final class TodayViewModelTests: XCTestCase {

    /// Fresh store per test; kept alive by the test instance for the models it creates.
    private lazy var container: ModelContainer = try! ModelContainer.inMemoryForTests()
    private var context: ModelContext { container.mainContext }

    private func makeNutrient(_ name: String, target: Double, reminderHours: [Int] = [],
                              goalType: GoalType = .minimum, sortOrder: Int = 0) -> Nutrient {
        let nutrient = Nutrient(name: name, unit: "mg", step: 100, dailyTarget: target, sortOrder: sortOrder, goalType: goalType)
        context.insert(nutrient)
        for hour in reminderHours {
            let time = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
            context.insert(NutrientReminder(nutrient: nutrient, timeOfDay: time))
        }
        return nutrient
    }

    private func refreshedViewModel() throws -> TodayViewModel {
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))
        try context.save()
        let viewModel = TodayViewModel()
        viewModel.refresh(context: context)
        return viewModel
    }

    /// 00:00 today, so every reminder hour later today is still upcoming.
    private var startOfToday: Date { Calendar.current.startOfDay(for: .now) }

    func testDayScoreCountsMetGoalsAcrossGroups() throws {
        let vitaminD = makeNutrient("Vitamin D", target: 400, sortOrder: 0)
        _ = makeNutrient("Omega-3", target: 2000, sortOrder: 1)
        _ = makeNutrient("Caffeine", target: 400, goalType: .maximum, sortOrder: 2)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 400))

        let viewModel = try refreshedViewModel()
        XCTAssertEqual(viewModel.dayScore, DayScore(met: 2, total: 3))  // Vitamin D met, Caffeine under its limit
    }

    func testPicksTheEarliestReminderAmongShownNutrients() throws {
        _ = makeNutrient("Magnesium", target: 400, reminderHours: [21], sortOrder: 0)
        _ = makeNutrient("Vitamin D", target: 4000, reminderHours: [9, 13], sortOrder: 1)

        let viewModel = try refreshedViewModel()
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Vitamin D")
    }

    func testIntakeLoggedOutsideTodayDoesNotHideTheReminder() throws {
        // Widget / Watch / another device: nothing suppressed this device's notification.
        let vitaminD = makeNutrient("Vitamin D", target: 4000, reminderHours: [9], sortOrder: 0)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000))

        let viewModel = try refreshedViewModel()
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Vitamin D")
    }

    func testLoggingFromTodayHidesTheReminderUntilTheNextReschedule() throws {
        let vitaminD = makeNutrient("Vitamin D", target: 4000, reminderHours: [9], sortOrder: 0)
        _ = makeNutrient("Magnesium", target: 400, reminderHours: [21], sortOrder: 1)
        let viewModel = try refreshedViewModel()

        viewModel.increment(vitaminD, context: context)
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Magnesium")

        // Foreground reschedule restores every reminder, so the card shows Vitamin D again.
        viewModel.rescheduleReminders(context: context)
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Vitamin D")
    }
}
