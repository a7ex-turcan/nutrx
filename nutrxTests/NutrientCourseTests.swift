import SwiftData
import XCTest
@testable import nutrx

/// Nutrients taken for a set time (#99): the day maths, the words, and every rule that drops a course after its last
/// day (History and streaks, reminders, stacks, Today).
final class NutrientCourseTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func testDays() {
        XCTAssertEqual(NutrientCourse.lastDay(days: 5, from: day(10, 20, hour: 9), calendar: calendar), day(10, 24),
                       "five days counting the first")
        XCTAssertEqual(NutrientCourse.lastDay(days: 0, from: day(10, 20), calendar: calendar), day(10, 20), "at least one")
        XCTAssertEqual(NutrientCourse.dayCount(from: day(10, 20, hour: 15), to: day(10, 24), calendar: calendar), 5)
        XCTAssertFalse(NutrientCourse.hasEnded(day(10, 24), by: day(10, 24, hour: 23), calendar: calendar), "the last day is in")
        XCTAssertTrue(NutrientCourse.hasEnded(day(10, 24), by: day(10, 25), calendar: calendar))
        XCTAssertFalse(NutrientCourse.hasEnded(nil, by: day(12, 31), calendar: calendar), "ongoing never ends")
    }

    func testWords() {
        let text = CourseText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.summary(endDate: nil, now: day(10, 20)), "Ongoing")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 20, hour: 9)), "Until Sat 24 Oct · 5 days")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 24, hour: 9)), "Last day today")
        XCTAssertEqual(text.summary(endDate: day(10, 24), now: day(10, 26)), "Ended 24 Oct")
    }

    func testHistoryCountsACourseOnlyUpToItsLastDay() {
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isDeleted: false, endDate: day(10, 5))
        let log = HistoryLog(nutrients: [nutrient], totals: [day(10, 5): [id: 1], day(10, 6): [id: 1]],
                             today: day(10, 10), calendar: calendar)
        XCTAssertEqual(log.day(day(10, 5)).goals.map(\.nutrientID), [id])
        XCTAssertTrue(log.day(day(10, 6)).goals.isEmpty, "after the last day it doesn't count")
        XCTAssertEqual(log.day(day(10, 6)).otherLogged.map(\.nutrientID), [id], "but a log that day still shows")
    }

    func testRemindersStopAfterTheLastDay() {
        let id = UUID()
        let plan = ReminderSchedule.Plan(nutrientID: id, times: [.init(hour: 9, minute: 0)], loggedToday: false,
                                         lastDay: day(10, 22))
        let occurrences = ReminderSchedule.occurrences(for: [plan], now: day(10, 20, hour: 7), calendar: calendar)
        XCTAssertEqual(occurrences.map(\.fireDate), [day(10, 20, hour: 9), day(10, 21, hour: 9), day(10, 22, hour: 9)])
    }

    func testStacksAndTodaySkipAnEndedCourse() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))  // Today's sections need it
        let course = Nutrient(name: "Antibiotic", unit: "mg", step: 500, dailyTarget: 1000, sortOrder: 0)
        let ongoing = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 1)
        context.insert(course)
        context.insert(ongoing)
        course.endDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))
        let stack = LogStack(name: "Morning", sortOrder: 0)
        context.insert(stack)
        _ = StackLogging.add(course, to: stack, context: context)
        _ = StackLogging.add(ongoing, to: stack, context: context)
        try context.save()

        XCTAssertFalse(course.isRunning())
        XCTAssertTrue(ongoing.isRunning())
        XCTAssertEqual(StackLogging.activeEntries(of: stack).compactMap(\.nutrient?.name), ["Vitamin D"])
        XCTAssertEqual(NutrientEntityQuery.activeNutrients(in: context).map(\.name), ["Vitamin D"], "Siri")
        let today = TodayViewModel()
        today.refresh(context: context)
        XCTAssertEqual(today.groupSections.flatMap { $0.intakes.map(\.nutrient.name) }, ["Vitamin D"])
    }
}
