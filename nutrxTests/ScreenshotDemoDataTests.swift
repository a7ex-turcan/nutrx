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
        // Six goals on each counted day: seven, or six on a Sunday evening (Sunday counts once it's over).
        let counted = (Calendar.current.dateComponents([.day], from: recap.weekStart, to: recap.lastDay).day ?? 0) + 1
        XCTAssertEqual(recap.goalsCounted, 6 * counted)
        XCTAssertNotNil(recap.steadiest)
        XCTAssertNotNil(recap.streak)
        XCTAssertEqual(recap.weakestWeekday?.weekday, 1, "Vitamin D's Sundays, as on the heatmap")
        XCTAssertTrue(RecapPhrasing.isAcceptable(text.summary, for: text), "the template passes its own check")
    }

    /// The recap names Sunday on every day of the week, mornings and Sunday evenings included: the demo data is
    /// relative to today, and on Mondays to Wednesdays another weekday used to tie with Sunday (#164).
    func testTheRecapNamesSundayWhateverTheDay() throws {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!  // a Monday
        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            for hour in [10, 20] {
                let now = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
                let container = try ModelContainer.inMemoryForTests()
                ScreenshotDemoData.replaceStore(in: container.mainContext, now: now)
                let history = HistoryViewModel()
                history.refresh(context: container.mainContext, now: now)
                let log = try XCTUnwrap(history.log)
                let names = Dictionary(try container.mainContext.fetch(FetchDescriptor<Nutrient>()).map { ($0.id, $0.name) },
                                       uniquingKeysWith: { first, _ in first })
                let recap = WeeklyRecap.build(log: log, names: names, week: WeeklyRecap.latestWeek(at: now, calendar: calendar),
                                              streaksEnabled: true)
                XCTAssertEqual(recap.weakestWeekday?.weekday, 1, "on \(now.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    func testOneWeeksRecapFromThatWeeksEntriesMatchesTheFullHistory() throws {
        // Today's card and the notification read only the week's entries; the facts must be the same.
        let week = WeeklyRecap.latestWeek(at: .now, calendar: .current)
        let (log, nutrients) = HistoryViewModel.loadLog(context: context)
        let names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let full = WeeklyRecap.build(log: log, names: names, week: week, streaksEnabled: false)
        let partial = try XCTUnwrap(RecapViewModel.recap(forWeek: week, context: context))
        XCTAssertNil(partial.streak, "a week-only recap has no streak to show")
        XCTAssertEqual(partial.goalsMet, full.goalsMet)
        XCTAssertEqual(partial.goalsCounted, full.goalsCounted)
        XCTAssertEqual(partial.fullDayFlags, full.fullDayFlags)
        XCTAssertEqual(partial.steadiest, full.steadiest)
        XCTAssertEqual(RecapText(partial).notificationBody, RecapText(full).notificationBody)
    }

    func testReplacingTwiceLeavesOneSet() throws {
        ScreenshotDemoData.replaceStore(in: context)
        XCTAssertEqual(try nutrients().count, 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
    }
}
