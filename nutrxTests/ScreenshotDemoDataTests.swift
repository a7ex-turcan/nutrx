import XCTest
import SwiftData
@testable import nutrx

/// Keeps the App Store demo set honest when the goal or streak rules change: the screenshots promise a 10-day
/// streak, 3/6 goals met today and "Sundays are your weakest day" for Vitamin D.
@MainActor
final class ScreenshotDemoDataTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
        ScreenshotDemoData.replaceStore(in: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func nutrients() throws -> [Nutrient] {
        try context.fetch(FetchDescriptor<Nutrient>())
    }

    /// Each nutrient's total per calendar day.
    private func totals(for nutrient: Nutrient) -> [Date: Double] {
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]
        for record in nutrient.intakeRecords ?? [] {
            totals[calendar.startOfDay(for: record.date), default: 0] += record.amount
        }
        return totals
    }

    func testCurrentStreakIsTenDays() {
        XCTAssertEqual(StreakService.compute(context: context).current, 10)
    }

    func testBestStreakIsLongerThanTheCurrentOne() {
        XCTAssertGreaterThan(StreakService.compute(context: context).best, 10)
    }

    func testThreeOfSixGoalsAreMetToday() throws {
        let today = Calendar.current.startOfDay(for: .now)
        let progresses = try nutrients().map { GoalProgress(nutrient: $0, current: totals(for: $0)[today] ?? 0) }
        let score = DayScore(progresses: progresses)
        XCTAssertEqual(score.met, 3)
        XCTAssertEqual(score.total, 6)
    }

    func testVitaminDWeakestDayIsSunday() throws {
        let vitaminD = try XCTUnwrap(try nutrients().first { $0.name == "Vitamin D" })
        let pattern = WeekdayPattern(totals: totals(for: vitaminD), goal: AnalyticsGoal(nutrient: vitaminD),
                                     createdAt: vitaminD.createdAt, today: .now)
        XCTAssertEqual(pattern.weakestWeekday, 1)
    }

    func testLastWeeksRecapHasSomethingToSay() throws {
        let history = HistoryViewModel()
        history.refresh(context: context)
        let log = try XCTUnwrap(history.log)
        let names = Dictionary(try nutrients().map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let week = WeeklyRecap.latestWeek(at: .now, calendar: .current)
        let recap = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: true)
        let text = RecapText(recap)
        XCTAssertTrue(recap.hasData)
        XCTAssertEqual(recap.goalsCounted, 42, "six goals, seven days")
        XCTAssertNotNil(recap.steadiest)
        XCTAssertNotNil(recap.streak)
        XCTAssertEqual(recap.weakestWeekday?.weekday, 1, "Vitamin D's Sundays, as on the heatmap")
        XCTAssertTrue(RecapPhrasing.isAcceptable(text.summary, for: text), "the template passes its own check")
    }

    func testReplacingTwiceLeavesOneSet() throws {
        ScreenshotDemoData.replaceStore(in: context)
        XCTAssertEqual(try nutrients().count, 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
    }
}
