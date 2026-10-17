import SwiftData
import XCTest
@testable import nutrx

/// Nutrients taken for a set time (#99): the day maths, restarts, and every rule that drops a course after its last
/// day (History and streaks, analytics, reminders, stacks, Today).
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

    func testHistoryCountsACourseOnlyUpToItsLastDay() {
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isRemoved: false, endDate: day(10, 5))
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

    func testARestartKeepsTheDaysSinceTheEndAsAGap() throws {
        let container = try ModelContainer.inMemoryForTests()
        let nutrient = Nutrient(name: "Antibiotic", unit: "mg", step: 500, dailyTarget: 1000, sortOrder: 0)
        container.mainContext.insert(nutrient)
        nutrient.endDate = day(10, 16)
        nutrient.setCourse(endDate: nil, now: day(10, 20, hour: 9), calendar: calendar)
        XCTAssertNil(nutrient.endDate)
        XCTAssertEqual(nutrient.courseGapsRaw, "20261017-20261019")
        // Restarting the day after it ended leaves no gap; a running course isn't a restart.
        XCTAssertNil(NutrientCourse.gap(after: day(10, 16), restartingOn: day(10, 17), calendar: calendar))
        XCTAssertNil(NutrientCourse.gap(after: day(10, 30), restartingOn: day(10, 20), calendar: calendar))
        let gaps = [day(10, 1)...day(10, 3), day(10, 9)...day(10, 9)]
        XCTAssertEqual(NutrientCourse.decode(NutrientCourse.encode(gaps, calendar: calendar), calendar: calendar), gaps)
    }

    func testAGapStaysTheSameDaysAfterATimeZoneChange() {
        for (from, to) in [("Europe/Istanbul", "UTC"), ("UTC", "Asia/Tokyo"), ("America/Los_Angeles", "Europe/London")] {
            var saved = Calendar(identifier: .gregorian)
            saved.timeZone = TimeZone(identifier: from)!
            var read = Calendar(identifier: .gregorian)
            read.timeZone = TimeZone(identifier: to)!
            func at(_ calendar: Calendar, _ day: Int) -> Date {
                calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
            }
            let gap = NutrientCourse.gap(after: at(saved, 14), restartingOn: at(saved, 17), calendar: saved)!
            let gaps = NutrientCourse.decode(NutrientCourse.encode([gap], calendar: saved), calendar: read)
            XCTAssertTrue(NutrientCourse.includes(nil, gaps: gaps, day: at(read, 14), calendar: read), "\(from) → \(to)")
            XCTAssertFalse(NutrientCourse.includes(nil, gaps: gaps, day: at(read, 15), calendar: read), "\(from) → \(to)")
            XCTAssertFalse(NutrientCourse.includes(nil, gaps: gaps, day: at(read, 16), calendar: read), "\(from) → \(to)")
            XCTAssertTrue(NutrientCourse.includes(nil, gaps: gaps, day: at(read, 17), calendar: read), "\(from) → \(to)")
        }
    }

    func testHistorySkipsTheGapBetweenACourseAndItsRestart() {
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isRemoved: false, endDate: nil, courseGaps: [day(10, 17)...day(10, 19)])
        let log = HistoryLog(nutrients: [nutrient], totals: [day(10, 16): [id: 1], day(10, 20): [id: 1]],
                             today: day(10, 25), calendar: calendar)
        XCTAssertEqual(log.day(day(10, 16)).goals.map(\.nutrientID), [id])
        XCTAssertTrue(log.day(day(10, 18)).goals.isEmpty, "not a miss: it was paused")
        XCTAssertEqual(log.day(day(10, 20)).goals.map(\.nutrientID), [id], "counts again from the restart")
    }

    func testAFinishedCourseDoesntBreakTheStreak() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)!.addingTimeInterval(9 * 3600) }
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 1000, sortOrder: 0)
        let course = Nutrient(name: "Antibiotic", unit: "mg", step: 500, dailyTarget: 500, sortOrder: 1)
        for nutrient in [vitaminD, course] {
            nutrient.createdAt = daysAgo(8)
            context.insert(nutrient)
        }
        course.endDate = cal.startOfDay(for: daysAgo(5))
        for n in 1...8 { context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000, date: daysAgo(n))) }
        for n in 5...8 { context.insert(IntakeRecord(nutrient: course, amount: 500, date: daysAgo(n))) }
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 8, "the days after the course ended aren't misses")
    }

    func testAnalyticsCountOnlyTheCoursesDays() {
        let goal = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)
        let summary = AnalyticsSummary(dayCount: 7, totals: [day(10, 20): 1, day(10, 21): 1], goal: goal,
                                       createdAt: day(10, 1), endDate: day(10, 21),
                                       courseGaps: [day(10, 15)...day(10, 16)], today: day(10, 22), calendar: calendar)
        let tracked = summary.days.filter(\.isTracked).map(\.date)
        XCTAssertEqual(tracked, [day(10, 17), day(10, 18), day(10, 19), day(10, 20), day(10, 21)],
                       "not the gap, not after the last day")
        // Created Thu 8 Oct, last day Wed 14 Oct, paused Sat 10 – Sun 11: every counted day met.
        let met = Dictionary(uniqueKeysWithValues: [8, 9, 12, 13, 14].map { (day(10, $0), 1.0) })
        let pattern = WeekdayPattern(totals: met, goal: goal, createdAt: day(10, 8), endDate: day(10, 14),
                                     courseGaps: [day(10, 10)...day(10, 11)], today: day(10, 22), calendar: calendar)
        let rates = Dictionary(uniqueKeysWithValues: pattern.entries.map { ($0.weekday, $0.hitRate) })
        XCTAssertEqual(rates[2], 1, "Monday 12 Oct counts; Monday 19 Oct is after the last day")
        XCTAssertNil(rates[7] ?? nil, "Saturday was paused")
        XCTAssertNil(rates[1] ?? nil, "Sunday was paused")
    }
}
