import SwiftData
import XCTest
@testable import nutrx

/// Stack reminders (#137, docs/pro/REMINDERS.md §4): their words, and a stack's usual time from a real store.
@MainActor
final class StackReminderTests: XCTestCase {
    func testTheWords() {
        XCTAssertEqual(StackReminderText.title(stackName: "Morning"), "Time for your Morning stack")
        XCTAssertEqual(StackReminderText.title(stackName: "Morning stack"), "Time for your Morning stack")
        XCTAssertEqual(StackReminderText.body(names: ["Vitamin D", "Omega-3", "Magnesium"]),
                       "Vitamin D, Omega-3 and Magnesium")
        XCTAssertEqual(StackReminderText.body(names: []), "Tap to log it.")
        XCTAssertNil(StackReminderText.ownRemindersNote(names: []))
        XCTAssertEqual(StackReminderText.ownRemindersNote(names: ["Vitamin D"]),
                       "Vitamin D has a reminder of its own too.")
        XCTAssertEqual(StackReminderText.ownRemindersNote(names: ["Vitamin D", "Omega-3"]),
                       "Vitamin D and Omega-3 have reminders of their own too.")
    }

    func testTheRow() {
        XCTAssertEqual(StackReminderText.summary(minutes: -1, atUsualTime: false, usual: .learning(samples: 0),
                                                 isPro: true), "None")
        let nine = UsualTimeText.time(540)
        XCTAssertEqual(StackReminderText.summary(minutes: 540, atUsualTime: false, usual: .learning(samples: 0),
                                                 isPro: true), nine)
        XCTAssertEqual(StackReminderText.summary(minutes: 540, atUsualTime: true, usual: .learning(samples: 2),
                                                 isPro: true), "Learning (\(nine))")
        XCTAssertEqual(StackReminderText.summary(minutes: 540, atUsualTime: true,
                                                 usual: .learned(weekdays: 510, weekends: 510), isPro: true),
                       "Usually by \(UsualTimeText.time(510))")
        XCTAssertEqual(StackReminderText.summary(minutes: 540, atUsualTime: true,
                                                 usual: .learned(weekdays: 510, weekends: 510), isPro: false), nine,
                       "without Pro its set time fires")
    }

    func testAStacksUsualTimeIsWhenEveryNutrientInItWasLogged() throws {
        let calendar = Calendar.current
        let context = ModelContext(try ModelContainer.inMemoryForTests())
        let today = calendar.startOfDay(for: .now)
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 1000, sortOrder: 0)
        let omega = Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 500, sortOrder: 1)
        for nutrient in [vitaminD, omega] {
            nutrient.createdAt = calendar.date(byAdding: .day, value: -30, to: today)!
            context.insert(nutrient)
        }
        let stack = LogStack(name: "Morning", sortOrder: 0)
        context.insert(stack)
        for (index, nutrient) in [vitaminD, omega].enumerated() {
            let entry = LogStackEntry(nutrient: nutrient, amount: nutrient.step, sortOrder: index)
            entry.stack = stack
            context.insert(entry)
        }
        // Ten days: Vitamin D at 7:50, Omega-3 at 8:20, so the stack is done at 8:20.
        for back in 1...10 {
            let day = calendar.date(byAdding: .day, value: -back, to: today)!
            context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000,
                                        date: calendar.date(bySettingHour: 7, minute: 50, second: 0, of: day)!))
            context.insert(IntakeRecord(nutrient: omega, amount: 500,
                                        date: calendar.date(bySettingHour: 8, minute: 20, second: 0, of: day)!))
        }
        try context.save()
        XCTAssertEqual(stack.usualTime(), .learned(weekdays: 500, weekends: 500))
    }
}
