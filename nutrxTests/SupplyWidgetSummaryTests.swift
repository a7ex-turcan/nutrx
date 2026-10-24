import XCTest
import SwiftData
@testable import nutrx

/// The supply & courses widget's list (#138, docs/pro/WIDGETS.md §4).
@MainActor
final class SupplyWidgetSummaryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 12))!

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    private func nutrient(_ name: String) -> Nutrient {
        let nutrient = Nutrient(name: name, unit: "IU", step: 1000, dailyTarget: 2000, sortOrder: 0)
        nutrient.createdAt = day(-30)
        context.insert(nutrient)
        return nutrient
    }

    /// A bottle of `servings` × 1,000 refilled 5 days ago, with 2,000 logged on each of the last 4 days.
    private func bottle(_ name: String, servings: Double) -> Nutrient {
        let nutrient = nutrient(name)
        nutrient.supplyServings = servings
        nutrient.supplyRefilledAt = day(-5)
        for offset in -4 ... -1 {
            context.insert(IntakeRecord(nutrient: nutrient, amount: 2000, date: day(offset).addingTimeInterval(9 * 3600)))
        }
        return nutrient
    }

    private func course(_ name: String, lastDayIn days: Int) -> Nutrient {
        let nutrient = nutrient(name)
        nutrient.endDate = day(days)
        return nutrient
    }

    private func item(_ name: String, _ kind: SupplyWidgetSummary.Item.Kind, out: Bool = false,
                      days: Int) -> SupplyWidgetSummary.Item {
        .init(nutrientID: UUID(), name: name, tint: .amber, symbolName: "sun.max", kind: kind, isOut: out,
              daysLeft: days)
    }

    // MARK: - Ordering

    func testOutFirstThenFewestDaysThenBottlesBeforeCourses() {
        let items = [
            item("Magnesium", .supply, days: 6),
            item("Iron", .course, days: 0),
            item("Zinc", .supply, days: 0),
            item("Omega-3", .supply, out: true, days: 0),
            item("Vitamin C", .course, days: 3),
            item("B12", .supply, days: 3),
        ]
        XCTAssertEqual(SupplyWidgetSummary.ordered(items).map(\.name),
                       ["Omega-3", "Zinc", "Iron", "B12", "Vitamin C", "Magnesium"])
    }

    func testTiesKeepTodaysOrder() {
        let items = [item("Vitamin D", .supply, days: 2), item("Magnesium", .supply, days: 2)]
        XCTAssertEqual(SupplyWidgetSummary.ordered(items).map(\.name), ["Vitamin D", "Magnesium"])
    }

    // MARK: - Words

    func testDetails() {
        XCTAssertEqual(item("A", .supply, out: true, days: 0).detail, "out")
        XCTAssertEqual(item("A", .supply, days: 0).detail, "runs out today")
        XCTAssertEqual(item("A", .supply, days: 1).detail, "1 day left")
        XCTAssertEqual(item("A", .supply, days: 6).detail, "6 days left")
        XCTAssertEqual(item("A", .course, days: 0).detail, "last day")
        XCTAssertEqual(item("A", .course, days: 1).detail, "ends tomorrow")
        XCTAssertEqual(item("A", .course, days: 3).detail, "ends in 3 days")

        XCTAssertEqual(item("A", .supply, out: true, days: 0).shortDetail, "out")
        XCTAssertEqual(item("A", .supply, days: 0).shortDetail, "today")
        XCTAssertEqual(item("A", .supply, days: 1).shortDetail, "1 day")
        XCTAssertEqual(item("A", .supply, days: 6).shortDetail, "6 days")
        XCTAssertEqual(item("A", .course, days: 0).shortDetail, "last day")
        XCTAssertEqual(item("A", .course, days: 1).shortDetail, "tomorrow")
        XCTAssertEqual(item("A", .course, days: 3).shortDetail, "3 days")
    }

    func testTrackedLine() {
        XCTAssertEqual(SupplyWidgetSummary(items: [], bottles: 4, courses: 1).trackedLine, "4 bottles, 1 course")
        XCTAssertEqual(SupplyWidgetSummary(items: [], bottles: 1, courses: 0).trackedLine, "1 bottle")
        XCTAssertEqual(SupplyWidgetSummary(items: [], bottles: 0, courses: 2).trackedLine, "2 courses")
        XCTAssertEqual(SupplyWidgetSummary(items: [], bottles: 0, courses: 0).trackedLine,
                       "Set up supply or a course on a nutrient.")
    }

    // MARK: - From the store

    func testListsLowAndOutBottlesAndCoursesEndingWithinAWeek() throws {
        let low = bottle("Vitamin D", servings: 10)     // 2,000 left at 2,000 a day
        let out = bottle("Omega-3", servings: 8)        // all 8,000 used
        _ = bottle("Magnesium", servings: 120)          // plenty: counted, not listed
        let iron = course("Iron", lastDayIn: 3)
        _ = course("Antibiotic", lastDayIn: 10)         // counted, not listed yet
        _ = course("Zinc", lastDayIn: -1)               // ended: neither
        let removed = bottle("Biotin", servings: 8)
        removed.isRemoved = true
        try context.save()

        let summary = SupplyWidgetSummary.make(try context.fetch(FetchDescriptor<Nutrient>()).sorted { $0.name < $1.name },
                                               now: now, calendar: calendar)
        XCTAssertEqual(summary.items.map(\.name), ["Omega-3", "Vitamin D", "Iron"])
        XCTAssertEqual(summary.items.map(\.nutrientID), [out.id, low.id, iron.id])
        XCTAssertEqual(summary.items.first?.isOut, true)
        XCTAssertEqual(summary.items.last?.kind, .course)
        XCTAssertEqual(summary.items.last?.daysLeft, 3)
        XCTAssertEqual(summary.bottles, 3)
        XCTAssertEqual(summary.courses, 2)
    }

    func testACoursesLastDayIsListedAsToday() throws {
        let iron = course("Iron", lastDayIn: 0)
        let summary = SupplyWidgetSummary.make([iron], now: now, calendar: calendar)
        XCTAssertEqual(summary.items.map(\.detail), ["last day"])
    }

    func testNothingDueIsOnTrack() {
        let summary = SupplyWidgetSummary.make([nutrient("Vitamin D")], now: now, calendar: calendar)
        XCTAssertTrue(summary.items.isEmpty)
        XCTAssertEqual(summary.trackedLine, "Set up supply or a course on a nutrient.")
    }
}
