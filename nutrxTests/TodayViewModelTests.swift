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

    // MARK: - Deleting entries (log sheet)

    private func total(of nutrient: Nutrient, in viewModel: TodayViewModel) -> Double? {
        viewModel.groupSections.flatMap(\.intakes).first { $0.nutrient.persistentModelID == nutrient.persistentModelID }?.total
    }

    func testDeletingAnEntryLowersTodaysTotal() throws {
        let vitaminD = makeNutrient("Vitamin D", target: 4000)
        let first = IntakeRecord(nutrient: vitaminD, amount: 1000)
        context.insert(first)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000))
        let viewModel = try refreshedViewModel()
        XCTAssertEqual(total(of: vitaminD, in: viewModel), 2000)

        viewModel.deleteRecord(first, context: context)
        XCTAssertEqual(total(of: vitaminD, in: viewModel), 1000)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IntakeRecord>()), 1)
    }

    func testDeletingLeavesALoneDecrementAsARawNegativeTotal() throws {
        // +1000 then −1000, then the +1000 is deleted: the day sums to −1000, shown as 0.
        let vitaminD = makeNutrient("Vitamin D", target: 4000)
        let added = IntakeRecord(nutrient: vitaminD, amount: 1000)
        context.insert(added)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: -1000))
        let viewModel = try refreshedViewModel()

        viewModel.deleteRecord(added, context: context)
        XCTAssertEqual(total(of: vitaminD, in: viewModel), -1000)
        XCTAssertEqual(viewModel.groupSections[0].intakes[0].progress.current, 0)

        // The next + (step 100) keeps tracking the raw sum, matching what a fresh refresh computes,
        // instead of starting again from the displayed 0.
        viewModel.increment(vitaminD, context: context)
        XCTAssertEqual(total(of: vitaminD, in: viewModel), -900)
        viewModel.refresh(context: context)
        XCTAssertEqual(total(of: vitaminD, in: viewModel), -900)
    }

    // MARK: - Next reminder

    func testPicksTheEarliestReminderAmongShownNutrients() throws {
        _ = makeNutrient("Magnesium", target: 400, reminderHours: [21], sortOrder: 0)
        _ = makeNutrient("Vitamin D", target: 4000, reminderHours: [9, 13], sortOrder: 1)

        let viewModel = try refreshedViewModel()
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Vitamin D")
    }

    func testALogFromAnywhereHidesThatNutrientsReminderToday() throws {
        // Widget, Watch, Siri or another device: the record is what counts, and the scheduler skips the same
        // reminders on its next sync (#4).
        let vitaminD = makeNutrient("Vitamin D", target: 4000, reminderHours: [9], sortOrder: 0)
        _ = makeNutrient("Magnesium", target: 400, reminderHours: [21], sortOrder: 1)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000))

        let viewModel = try refreshedViewModel()
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Magnesium")
    }

    func testLoggingHidesTheReminderForTheRestOfTodayEvenAfterAReschedule() throws {
        let vitaminD = makeNutrient("Vitamin D", target: 4000, reminderHours: [9], sortOrder: 0)
        _ = makeNutrient("Magnesium", target: 400, reminderHours: [21], sortOrder: 1)
        let viewModel = try refreshedViewModel()

        viewModel.increment(vitaminD, context: context)
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Magnesium")

        // A foreground reschedule used to bring today's Vitamin D reminder back (#4); now it stays silenced.
        viewModel.rescheduleReminders(context: context)
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.nutrientName, "Magnesium")
    }

    func testTakingTodaysLogBackBringsTheReminderBack() throws {
        let vitaminD = makeNutrient("Vitamin D", target: 4000, reminderHours: [9], sortOrder: 0)
        let viewModel = try refreshedViewModel()
        viewModel.increment(vitaminD, context: context)
        XCTAssertNil(viewModel.nextReminder(after: startOfToday))

        viewModel.decrement(vitaminD, context: context)  // back to 0 today
        XCTAssertEqual(viewModel.nextReminder(after: startOfToday)?.time,
                       Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now))
    }
}
