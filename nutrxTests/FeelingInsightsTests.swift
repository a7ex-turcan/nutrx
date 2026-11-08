import XCTest
import SwiftData
@testable import nutrx

/// How you feel's line in the weekly and monthly recaps (nutrx Pro, #133, docs/pro/HOW-YOU-FEEL.md §3): the clearest
/// finding across the nutrients over the 28 days up to the period's last day.
@MainActor
final class FeelingInsightsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// The recap's last day.
    private var lastDay: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 29))! }

    /// `daysBefore` days before the last day (0 is the last day itself).
    private func day(_ daysBefore: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysBefore, to: lastDay)!
    }

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func nutrient(_ name: String, sortOrder: Int) -> Nutrient {
        let nutrient = Nutrient(name: name, unit: "mg", step: 100, dailyTarget: 400, sortOrder: sortOrder)
        nutrient.createdAt = day(60)
        context.insert(nutrient)
        return nutrient
    }

    /// Logs `nutrient` on each of the last 28 days: its goal on `met`, a quarter of it on the rest.
    private func log(_ nutrient: Nutrient, met: Set<Int>) {
        for daysBefore in 0..<28 {
            let amount = met.contains(daysBefore) ? 400.0 : 100.0
            context.insert(IntakeRecord(nutrient: nutrient, amount: amount,
                                        date: day(daysBefore).addingTimeInterval(9 * 3600)))
        }
    }

    /// Energy answered every day of the last 28: `high` on `met`, `low` on the rest.
    private func energy(high: Int, low: Int, on met: Set<Int>) {
        let question = FeelingQuestion(title: "Energy", kind: .scale, presetRaw: FeelingPreset.energy.rawValue,
                                       sortOrder: 0)
        context.insert(question)
        for daysBefore in 0..<28 {
            context.insert(FeelingAnswer(question: question, day: day(daysBefore),
                                         value: met.contains(daysBefore) ? high : low))
        }
    }

    func testNoQuestionsNoLine() {
        log(nutrient("Magnesium", sortOrder: 0), met: Set(0..<20))
        XCTAssertNil(FeelingInsights.recapLine(context: context, through: lastDay, calendar: calendar))
    }

    func testTheLineIsTheLargestFindingAcrossTheNutrients() throws {
        let met = Set(0..<20)
        energy(high: 5, low: 2, on: met)
        // Magnesium follows Energy exactly; Zinc is met on half of each, so its groups barely differ.
        log(nutrient("Magnesium", sortOrder: 0), met: met)
        log(nutrient("Zinc", sortOrder: 1), met: Set(stride(from: 0, to: 28, by: 2)))

        let best = try XCTUnwrap(FeelingInsights.clearest(context: context, through: lastDay, calendar: calendar))
        XCTAssertEqual(best.nutrient.name, "Magnesium")
        XCTAssertEqual(FeelingInsights.recapLine(context: context, through: lastDay, calendar: calendar),
                       "On days you reach your Magnesium goal, you rated your Energy 5.0 on average, vs 2.0 on other days.")
    }

    /// The trends read the 28 days up to the period's end, not up to now: a past week's line ignores what came after.
    func testOnlyTheDaysUpToTheLastDayCount() {
        let met = Set(0..<20)
        energy(high: 5, low: 2, on: met)
        log(nutrient("Magnesium", sortOrder: 0), met: met)
        // Three weeks earlier, only 7 of the answered days are in the window: not enough to pair.
        XCTAssertNil(FeelingInsights.recapLine(context: context, through: day(21), calendar: calendar))
        XCTAssertNotNil(FeelingInsights.recapLine(context: context, through: lastDay, calendar: calendar))
    }

    /// A removed nutrient, and one under a weekly schedule (whose days don't count one by one), never make the line.
    func testRemovedAndWeeklyNutrientsAreLeftOut() {
        let met = Set(0..<20)
        energy(high: 5, low: 2, on: met)
        let removed = nutrient("Magnesium", sortOrder: 0)
        log(removed, met: met)
        removed.isRemoved = true
        let weekly = nutrient("Zinc", sortOrder: 1)
        log(weekly, met: met)
        weekly.scheduleRaw = NutrientSchedule().setting(.weekly(times: 3), from: day(60), calendar: calendar)
            .encode(calendar: calendar)
        XCTAssertNil(FeelingInsights.recapLine(context: context, through: lastDay, calendar: calendar))
    }

    /// The App Store demo's latest recap carries a line: Sleep after Magnesium's days.
    func testTheDemoHasALine() throws {
        ScreenshotDemoData.replaceStore(in: context)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
        let best = try XCTUnwrap(FeelingInsights.clearest(context: context, through: yesterday))
        XCTAssertEqual(best.finding.question.preset, .sleep)
    }
}
