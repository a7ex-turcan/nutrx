import SwiftData
import XCTest
@testable import nutrx

/// The reminders sheet refuses a time that's already set (#163).
final class NutrientReminderTests: XCTestCase {
    func testFindsATimeAlreadySetWhateverTheDate() throws {
        let container = try ModelContainer.inMemoryForTests()
        let calendar = Calendar(identifier: .gregorian)
        let nutrient = Nutrient(name: "Iron", unit: "mg", step: 9, dailyTarget: 18, sortOrder: 0)
        container.mainContext.insert(nutrient)
        let nine = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9, minute: 0))!
        let reminders = [NutrientReminder(nutrient: nutrient, timeOfDay: nine)]

        let nineAnotherDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 0, second: 30))!
        XCTAssertTrue(NutrientReminder.hasReminder(at: nineAnotherDay, among: reminders, calendar: calendar))
        let nineOhOne = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 1))!
        XCTAssertFalse(NutrientReminder.hasReminder(at: nineOhOne, among: reminders, calendar: calendar))
        XCTAssertFalse(NutrientReminder.hasReminder(at: nine, among: [], calendar: calendar))
    }
}
