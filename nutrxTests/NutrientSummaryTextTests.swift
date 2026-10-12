import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §5.3 — the analytics header's goal line and the Reminders row summary.
final class NutrientSummaryTextTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let enGB = Locale(identifier: "en_GB")

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour, minute: minute))!
    }

    // MARK: - Goal line

    func testGoalLineWithGroup() {
        XCTAssertEqual(NutrientSummaryText.goalLine(goalType: .minimum, goalAmount: "4,000 IU", groupName: "Morning stack"),
                       "At least 4,000 IU a day · Morning stack")
    }

    func testGoalLineWithoutGroup() {
        XCTAssertEqual(NutrientSummaryText.goalLine(goalType: .maximum, goalAmount: "400 mg", groupName: nil),
                       "At most 400 mg a day")
        XCTAssertEqual(NutrientSummaryText.goalLine(goalType: .range, goalAmount: "120–160 g", groupName: nil),
                       "Between 120–160 g a day")
    }

    func testGoalLineLeavesOutTheGeneralGroup() throws {
        let container = try ModelContainer.inMemoryForTests()  // keep alive for the context's lifetime
        let context = container.mainContext
        let general = NutrientGroup(name: "General", sortOrder: 0, isSystem: true)
        let vitamins = NutrientGroup(name: "Vitamins", sortOrder: 1)
        let nutrient = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        context.insert(general)
        context.insert(vitamins)
        context.insert(nutrient)

        nutrient.group = general
        XCTAssertFalse(NutrientSummaryText.goalLine(for: nutrient).contains("·"))
        nutrient.group = vitamins
        XCTAssertTrue(NutrientSummaryText.goalLine(for: nutrient).hasSuffix("a day · Vitamins"))
    }

    // MARK: - Reminders

    /// The time as the summary formats it. Built from the same style so these tests check order, joining and
    /// the count rules — not the platform's locale data ("8:30" vs "08:30" differs across ICU versions).
    private func shortTime(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: enGB, calendar: calendar)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    func testNoReminders() {
        XCTAssertEqual(NutrientSummaryText.reminderSummary(times: [], calendar: calendar, locale: enGB), "None")
    }

    func testOneOrTwoRemindersListTheirTimesInOrder() {
        XCTAssertEqual(NutrientSummaryText.reminderSummary(times: [time(13)], calendar: calendar, locale: enGB),
                       shortTime(time(13)))
        XCTAssertEqual(NutrientSummaryText.reminderSummary(times: [time(20), time(8, 30)], calendar: calendar, locale: enGB),
                       "\(shortTime(time(8, 30))), \(shortTime(time(20)))")
    }

    func testThreeOrMoreRemindersAreCounted() {
        let times = [time(8), time(13), time(20)]
        XCTAssertEqual(NutrientSummaryText.reminderSummary(times: times, calendar: calendar, locale: enGB), "3 a day")
    }
}
