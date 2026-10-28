import SwiftData
import XCTest
@testable import nutrx

/// Which month and year the Recaps screen opens on and offers (#136, docs/pro/RECAPS.md §5), on a real store.
@MainActor
final class RecapViewModelTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// One nutrient met every day from `from` through `through`.
    private func store(from: Date, through: Date) throws -> ModelContext {
        let context = ModelContext(try ModelContainer.inMemoryForTests())
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 1000, sortOrder: 0)
        vitaminD.createdAt = calendar.startOfDay(for: from)
        context.insert(vitaminD)
        var day = from
        while day <= through {
            context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000, date: day))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        try context.save()
        return context
    }

    private func monthStart(_ year: Int, _ month: Int) -> Date {
        calendar.startOfDay(for: date(year, month, 1))
    }

    func testTheMonthTabOpensOnLastMonthWithTheMonthSoFarAfterIt() throws {
        let context = try store(from: date(2026, 6, 1), through: date(2026, 10, 27))
        let model = RecapViewModel()
        model.refresh(context: context, streaksEnabled: true, now: date(2026, 10, 28))
        XCTAssertEqual(model.monthChoices.map(\.monthStart),
                       [6, 7, 8, 9, 10].map { monthStart(2026, $0) })
        XCTAssertEqual(model.selectedMonthRecap?.monthStart, monthStart(2026, 9), "last whole month")
        XCTAssertEqual(model.monthChoices.last?.isMonthOver, false, "October so far")

        // On the 1st nothing of November has counted yet: no month so far, and October is whole.
        model.refresh(context: context, streaksEnabled: true, now: date(2026, 11, 1, hour: 9))
        XCTAssertEqual(model.monthChoices.last?.monthStart, monthStart(2026, 10))
        XCTAssertEqual(model.selectedMonthRecap?.monthStart, monthStart(2026, 10))
        XCTAssertEqual(model.selectedMonthRecap?.isMonthOver, true)
    }

    func testAPickedMonthThatLeavesTheListFallsBackToTheDefault() throws {
        let context = try store(from: date(2026, 6, 1), through: date(2026, 10, 27))
        let model = RecapViewModel()
        model.refresh(context: context, streaksEnabled: true, now: date(2026, 10, 28))
        model.selectedMonth = monthStart(2026, 6)
        XCTAssertEqual(model.selectedMonthRecap?.monthStart, monthStart(2026, 6))

        // A year on, June 2026 is past the twelve months.
        model.refresh(context: context, streaksEnabled: true, now: date(2027, 7, 15))
        XCTAssertNil(model.selectedMonth)
        XCTAssertEqual(model.selectedMonthRecap?.monthStart, monthStart(2026, 10), "the newest month with something in it")
    }

    func testTheMonthPickerNeverNamesAMonthTwice() throws {
        let context = try store(from: date(2025, 9, 1), through: date(2026, 10, 27))
        let model = RecapViewModel()
        model.refresh(context: context, streaksEnabled: true, now: date(2026, 10, 28))
        XCTAssertEqual(model.monthChoices.count, RecapViewModel.monthCount)
        let months = model.monthChoices.map { calendar.component(.month, from: $0.monthStart) }
        XCTAssertEqual(Set(months).count, months.count, "October 2025 makes way for October so far")
        XCTAssertEqual(model.monthChoices.first?.monthStart, monthStart(2025, 11))
    }

    func testTheYearTabOpensOnTheYearSoFarExceptInJanuary() throws {
        let context = try store(from: date(2026, 3, 1), through: date(2027, 1, 14))
        let model = RecapViewModel()

        model.refresh(context: context, streaksEnabled: true, now: date(2026, 10, 28))
        XCTAssertEqual(model.selectedYearRecap?.isYearOver, false, "2026 so far")
        XCTAssertEqual(model.yearChoices.count, 1)

        // In January the year just ended, with the new year so far after it once it has a completed day.
        model.refresh(context: context, streaksEnabled: true, now: date(2027, 1, 15))
        XCTAssertEqual(model.selectedYearRecap?.yearStart, calendar.startOfDay(for: date(2026, 1, 1)))
        XCTAssertEqual(model.selectedYearRecap?.isYearOver, true)
        XCTAssertEqual(model.yearChoices.map(\.isYearOver), [true, false])

        // On 1 January nothing of the new year has counted: only 2026.
        model.refresh(context: context, streaksEnabled: true, now: date(2027, 1, 1, hour: 9))
        XCTAssertEqual(model.yearChoices.count, 1)
        XCTAssertEqual(model.selectedYearRecap?.isYearOver, true)
    }
}
