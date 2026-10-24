import XCTest
import SwiftData
@testable import nutrx

/// What the Log stack and Log nutrient controls show (#138, docs/pro/WIDGETS.md §2).
@MainActor
final class ControlTextTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let calendar = Calendar.current
    private let en = Locale(identifier: "en_US")

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func nutrient(_ name: String, unit: String = "IU", step: Double = 1000) -> Nutrient {
        let item = Nutrient(name: name, unit: unit, step: step, dailyTarget: 4000, sortOrder: 0)
        context.insert(item)
        return item
    }

    private func morning() -> (LogStack, Nutrient) {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let vitaminD = nutrient("Vitamin D")
        StackLogging.add(vitaminD, to: stack, context: context)
        return (stack, vitaminD)
    }

    // MARK: - Log stack

    func testAStackReadsLogUntilLoggedToday() {
        let (stack, _) = morning()
        XCTAssertEqual(ControlText.state(of: stack, isPro: true), .ready)
        XCTAssertEqual(ControlText.text(.ready), "Log")

        XCTAssertEqual(ControlText.symbol(.ready), "square.stack.3d.up")

        StackLogging.log(stack, context: context)
        XCTAssertEqual(ControlText.state(of: stack, isPro: true), .loggedToday)
        XCTAssertEqual(ControlText.text(.loggedToday), "Logged today")
        XCTAssertEqual(ControlText.symbol(.loggedToday), "checkmark.circle.fill", "the small control shows only this")
    }

    func testYesterdaysLogDoesntCount() {
        let (stack, _) = morning()
        stack.lastLoggedAt = calendar.date(byAdding: .day, value: -1, to: .now)
        XCTAssertEqual(ControlText.state(of: stack, isPro: true), .ready)
    }

    func testAStackWithNothingDueSaysSo() {
        let (stack, vitaminD) = morning()
        vitaminD.isRemoved = true
        XCTAssertEqual(ControlText.state(of: stack, isPro: true), .nothingDue)
        XCTAssertEqual(ControlText.text(.nothingDue), "Nothing due today")

        let empty = StackLogging.createStack(named: "Evening", context: context)
        XCTAssertEqual(ControlText.state(of: empty, isPro: true), .nothingDue)
    }

    func testAGoneStackReadsRemoved() {
        XCTAssertEqual(ControlText.state(of: nil as LogStack?, isPro: true), .removed)
        XCTAssertEqual(ControlText.text(ControlText.StackState.removed), "Removed in nutrx")
    }

    func testFreeComesFirst() {
        let (stack, _) = morning()
        XCTAssertEqual(ControlText.state(of: stack, isPro: false), .free)
        XCTAssertEqual(ControlText.state(of: nil as LogStack?, isPro: false), .free)
        XCTAssertEqual(ControlText.text(ControlText.StackState.free), "nutrx Pro")
    }

    // MARK: - Log nutrient

    func testANutrientShowsWhatATapLogs() {
        let vitaminD = nutrient("Vitamin D")
        let state = ControlText.state(of: vitaminD, isPro: true)
        XCTAssertEqual(state, .ready(step: 1000, unit: "IU"))
        XCTAssertEqual(ControlText.text(state, locale: en), "+1,000 IU")
        XCTAssertEqual(ControlText.text(.ready(step: 0.5, unit: ""), locale: en), "+0.5")
    }

    func testARemovedNutrientSaysSo() {
        let vitaminD = nutrient("Vitamin D")
        vitaminD.isRemoved = true
        XCTAssertEqual(ControlText.state(of: vitaminD, isPro: true), .removed)
        XCTAssertEqual(ControlText.state(of: nil as Nutrient?, isPro: true), .removed)
        XCTAssertEqual(ControlText.text(ControlText.NutrientState.removed), "Removed in nutrx")
    }

    func testAnEndedCourseSaysSo() {
        let iron = nutrient("Iron", unit: "mg", step: 18)
        iron.endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: .now)!)
        XCTAssertEqual(ControlText.state(of: iron, isPro: true), .courseEnded)
        XCTAssertEqual(ControlText.text(ControlText.NutrientState.courseEnded), "Course ended")

        iron.endDate = calendar.startOfDay(for: .now)
        XCTAssertEqual(ControlText.state(of: iron, isPro: true), .ready(step: 18, unit: "mg"), "the last day still logs")
    }

    func testAFreeNutrientControlReadsPro() {
        XCTAssertEqual(ControlText.state(of: nutrient("Vitamin D"), isPro: false), .free)
        XCTAssertEqual(ControlText.text(ControlText.NutrientState.free), "nutrx Pro")
    }

    func testANutrientOffTodaySaysSo() {
        // Due only on the weekday after today's, from a week ago (1 = Sunday).
        let today = calendar.component(.weekday, from: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now)!
        let vitaminD = nutrient("Vitamin D")
        vitaminD.scheduleRaw = NutrientSchedule()
            .setting(.weekdays([today % 7 + 1]), from: weekAgo, calendar: calendar).encode(calendar: calendar)
        XCTAssertEqual(ControlText.state(of: vitaminD, isPro: true), .notDue)
        XCTAssertEqual(ControlText.text(ControlText.NutrientState.notDue), "Not due today")
    }

    // MARK: - Taps

    func testAStackTapLogsOnlyWhenThereIsSomethingNewToLog() {
        XCTAssertEqual(ControlText.tap(ControlText.StackState.ready), .log)
        XCTAssertEqual(ControlText.tap(ControlText.StackState.loggedToday), .open(.today),
                       "Log again with Undo is on Today, not one accidental tap away")
        XCTAssertEqual(ControlText.tap(ControlText.StackState.nothingDue), .nothing)
        XCTAssertEqual(ControlText.tap(ControlText.StackState.removed), .open(.today))
        XCTAssertEqual(ControlText.tap(ControlText.StackState.free), .open(.pro))
    }

    func testANutrientTapLogsOnlyWhenItCounts() {
        XCTAssertEqual(ControlText.tap(.ready(step: 1000, unit: "IU")), .log)
        XCTAssertEqual(ControlText.tap(ControlText.NutrientState.notDue), .open(.today))
        XCTAssertEqual(ControlText.tap(ControlText.NutrientState.courseEnded), .open(.nutrients))
        XCTAssertEqual(ControlText.tap(ControlText.NutrientState.removed), .open(.nutrients))
        XCTAssertEqual(ControlText.tap(ControlText.NutrientState.free), .open(.pro))
    }
}
