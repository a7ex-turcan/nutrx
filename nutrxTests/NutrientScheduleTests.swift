import SwiftData
import XCTest
@testable import nutrx

/// Schedules (#132, docs/pro/SCHEDULES.md): the stored form, dose days, changes that keep the days before, and the
/// weekly count.
final class NutrientScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026: Mon 19 Oct … Sun 25 Oct, Mon 26 Oct.
    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private func day(_ month: Int, _ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func schedule(_ raw: String) -> NutrientSchedule {
        NutrientSchedule.decode(raw, calendar: calendar)
    }

    // MARK: Stored form

    func testRoundTrip() {
        let raw = "20261019=days:2,4,6;20261026=cycle:5:2:20261026;20261102=week:3;20261109=daily"
        let decoded = schedule(raw)
        XCTAssertEqual(decoded.pieces.map(\.kind), [
            .weekdays([2, 4, 6]), .cycle(on: 5, off: 2, start: day(10, 26)), .weekly(times: 3), .everyDay,
        ])
        XCTAssertEqual(decoded.encode(calendar: calendar), raw)
        XCTAssertEqual(schedule("").pieces, [], "empty is every day")
        XCTAssertEqual(schedule("").encode(calendar: calendar), "")
    }

    func testDamagedPiecesAreSkipped() {
        let decoded = schedule("20261019=days:;2026102=week:3;20261020=week:7;20261021=cycle:0:2:20261021;"
                               + "20261022=nonsense;20261023=days:9;20261024=week:2")
        XCTAssertEqual(decoded.pieces, [NutrientSchedule.Piece(from: day(10, 24), kind: .weekly(times: 2))])
    }

    func testPiecesAreReadOldestFirst() {
        let decoded = schedule("20261026=week:3;20261019=days:1")
        XCTAssertEqual(decoded.pieces.map(\.from), [day(10, 19), day(10, 26)])
    }

    /// A stored day is a calendar day: read in another time zone it's still the same date and weekday.
    func testStoredDaysDontMoveWithTheTimeZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let decoded = NutrientSchedule.decode("20261019=days:2", calendar: tokyo)
        let monday = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        XCTAssertEqual(decoded.pieces.first?.from, monday)
        XCTAssertTrue(decoded.isDoseDay(monday, calendar: tokyo))
        XCTAssertEqual(decoded.encode(calendar: tokyo), "20261019=days:2")
    }

    // MARK: Dose days

    func testWeekdays() {
        let monWedFri = schedule("20261019=days:2,4,6")
        XCTAssertEqual((19...25).map { monWedFri.isDoseDay(day(10, $0), calendar: calendar) },
                       [true, false, true, false, true, false, false])
        let sundays = schedule("20261019=days:1")
        XCTAssertTrue(sundays.isDoseDay(day(10, 25), calendar: calendar))
        XCTAssertFalse(sundays.isDoseDay(day(10, 24), calendar: calendar))
    }

    func testCycles() {
        let fiveOnTwoOff = schedule("20261019=cycle:5:2:20261019")
        XCTAssertEqual((19...31).map { fiveOnTwoOff.isDoseDay(day(10, $0), calendar: calendar) },
                       [true, true, true, true, true, false, false, true, true, true, true, true, false])
        let everyOtherDay = schedule("20261019=cycle:1:1:20261019")
        XCTAssertEqual((19...23).map { everyOtherDay.isDoseDay(day(10, $0), calendar: calendar) },
                       [true, false, true, false, true])
        let everyThirdDay = schedule("20261019=cycle:1:2:20261019")
        XCTAssertEqual((19...25).map { everyThirdDay.isDoseDay(day(10, $0), calendar: calendar) },
                       [true, false, false, true, false, false, true])
    }

    /// Set today to start next Wednesday: not due until then.
    func testACycleIsntDueBeforeItsStart() {
        let later = schedule("20261019=cycle:3:4:20261021")
        XCTAssertFalse(later.isDoseDay(day(10, 19), calendar: calendar))
        XCTAssertFalse(later.isDoseDay(day(10, 20), calendar: calendar))
        XCTAssertTrue(later.isDoseDay(day(10, 21), calendar: calendar))
    }

    /// A cycle that started before the day it was set counts from its start.
    func testACycleCountsFromItsOwnStart() {
        let started = schedule("20261023=cycle:2:2:20261019")
        XCTAssertTrue(started.isDoseDay(day(10, 23), calendar: calendar), "19, 20 on; 21, 22 off; 23 on")
        XCTAssertFalse(started.isDoseDay(day(10, 25), calendar: calendar))
    }

    func testEveryDayAndWeeklyAreDueEveryDay() {
        for raw in ["", "20261019=daily", "20261019=week:3"] {
            XCTAssertTrue((19...25).allSatisfy { schedule(raw).isDoseDay(day(10, $0), calendar: calendar) }, raw)
        }
    }

    // MARK: Changes keep the days before

    func testAScheduleAppliesFromItsDay() {
        let tuesdaysOff = schedule("20261023=days:2,4,6")
        XCTAssertTrue(tuesdaysOff.isDoseDay(day(10, 20), calendar: calendar), "a Tuesday before it was set")
        XCTAssertFalse(tuesdaysOff.isDoseDay(day(10, 27), calendar: calendar))
        XCTAssertEqual(tuesdaysOff.kind(on: day(10, 22), calendar: calendar), .everyDay)
    }

    func testSetting() {
        let empty = NutrientSchedule()
        XCTAssertEqual(empty.setting(.everyDay, from: day(10, 23), calendar: calendar), empty,
                       "every day is already in effect")

        let monWedFri = empty.setting(.weekdays([2, 4, 6]), from: day(10, 23), calendar: calendar)
        XCTAssertEqual(monWedFri.encode(calendar: calendar), "20261023=days:2,4,6")

        let sameDay = monWedFri.setting(.weekly(times: 3), from: day(10, 23), calendar: calendar)
        XCTAssertEqual(sameDay.encode(calendar: calendar), "20261023=week:3", "a change the same day replaces it")

        let back = monWedFri.setting(.everyDay, from: day(10, 30), calendar: calendar)
        XCTAssertEqual(back.encode(calendar: calendar), "20261023=days:2,4,6;20261030=daily")
        XCTAssertFalse(back.isDoseDay(day(10, 27), calendar: calendar), "the Tuesday between still has the schedule")
        XCTAssertTrue(back.isDoseDay(day(11, 3), calendar: calendar))

        XCTAssertEqual(monWedFri.setting(.weekdays([2, 4, 6]), from: day(10, 30), calendar: calendar), monWedFri,
                       "the same schedule again changes nothing")
    }

    // MARK: Weekly

    /// Weeks run Monday to Sunday whatever the locale's first weekday, the same as the recap.
    func testWeeksStartOnMonday() {
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        XCTAssertEqual(NutrientSchedule.weekStart(of: day(10, 25), calendar: sundayFirst), day(10, 19))
        XCTAssertEqual(NutrientSchedule.weekStart(of: day(10, 26), calendar: sundayFirst), day(10, 26))
        XCTAssertEqual(NutrientSchedule.weekStart(of: day(10, 19), calendar: calendar),
                       WeeklyRecap.weekStart(containing: day(10, 19), calendar: calendar))
    }

    /// Only the first `times` met days of a week count; later ones that week are extra.
    func testWeeklyCountsTheFirstMetDays() {
        let thrice = schedule("20261019=week:3")
        let met = [day(10, 19), day(10, 20), day(10, 22), day(10, 24), day(10, 26)]
        XCTAssertEqual(thrice.weeklyCountedDays(met, calendar: calendar),
                       [day(10, 19), day(10, 20), day(10, 22), day(10, 26)])
        XCTAssertEqual(thrice.weekProgress(on: day(10, 21), metDays: met, calendar: calendar),
                       NutrientSchedule.WeekProgress(met: 3, times: 3))
        XCTAssertEqual(thrice.weekProgress(on: day(10, 27), metDays: met, calendar: calendar)?.met, 1)
        XCTAssertNil(schedule("20261019=days:2").weekProgress(on: day(10, 21), metDays: met, calendar: calendar))
    }

    /// Met days before a weekly schedule are the caller's to count, as every day.
    func testWeeklyLeavesOtherDaysAlone() {
        let fromWednesday = schedule("20261021=week:2")
        XCTAssertEqual(fromWednesday.weeklyCountedDays([day(10, 19), day(10, 21), day(10, 22), day(10, 23)],
                                                       calendar: calendar),
                       [day(10, 21), day(10, 22)])
    }

    func testWeekProgress() {
        let progress = NutrientSchedule.WeekProgress(met: 2, times: 3)
        XCTAssertFalse(progress.isDone)
        XCTAssertTrue(NutrientSchedule.WeekProgress(met: 3, times: 3).isDone)
    }

    /// A week only partly under a weekly schedule isn't judged.
    func testPartialWeeks() {
        let fromThursday = schedule("20261022=week:3")
        XCTAssertFalse(fromThursday.isWholeWeekly(weekStarting: day(10, 19), calendar: calendar))
        XCTAssertTrue(fromThursday.isWholeWeekly(weekStarting: day(10, 26), calendar: calendar))
        let changedMidWeek = schedule("20261019=week:3;20261029=week:2")
        XCTAssertTrue(changedMidWeek.isWholeWeekly(weekStarting: day(10, 19), calendar: calendar))
        XCTAssertFalse(changedMidWeek.isWholeWeekly(weekStarting: day(10, 26), calendar: calendar))
        XCTAssertFalse(schedule("20261019=days:2").isWholeWeekly(weekStarting: day(10, 19), calendar: calendar))
    }

    // MARK: On the nutrient

    func testCountsCombinesTheCourseAndTheSchedule() {
        let nutrient = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 1000, sortOrder: 0)
        nutrient.scheduleRaw = "20261019=days:2,4,6"
        nutrient.endDate = day(10, 23)
        XCTAssertTrue(nutrient.counts(on: day(10, 21), calendar: calendar))
        XCTAssertFalse(nutrient.counts(on: day(10, 22), calendar: calendar), "an off day")
        XCTAssertFalse(nutrient.counts(on: day(10, 26), calendar: calendar), "a Monday after the course")
        nutrient.endDate = nil
        XCTAssertTrue(nutrient.counts(on: day(10, 26), calendar: calendar))
    }

    /// Under a weekly schedule no day counts by the daily rule; the caller adds the met ones (`weeklyCountedDays`).
    func testCountsLeavesWeeklyDaysToTheCaller() {
        let nutrient = Nutrient(name: "Vitamin D", unit: "IU", step: 50000, dailyTarget: 50000, sortOrder: 0)
        nutrient.scheduleRaw = "20261021=week:1"
        XCTAssertTrue(nutrient.counts(on: day(10, 20), calendar: calendar), "every day before the schedule")
        XCTAssertFalse(nutrient.counts(on: day(10, 21), calendar: calendar))
        XCTAssertTrue(nutrient.isDue(on: day(10, 21), calendar: calendar), "but due on Today until the week is done")
    }

    /// A cycle built in code with no days at all is never due, rather than dividing by zero.
    func testAnEmptyCycleIsNeverDue() {
        let empty = NutrientSchedule().setting(.cycle(on: 0, off: 0, start: day(10, 19)), from: day(10, 19),
                                               calendar: calendar)
        XCTAssertFalse(empty.isDoseDay(day(10, 20), calendar: calendar))
    }

    func testIsDue() {
        let nutrient = Nutrient(name: "Magnesium", unit: "mg", step: 100, dailyTarget: 200, sortOrder: 0)
        nutrient.scheduleRaw = "20261019=days:1"
        XCTAssertTrue(nutrient.isDue(on: day(10, 25), calendar: calendar))
        XCTAssertFalse(nutrient.isDue(on: day(10, 24), calendar: calendar))
        XCTAssertTrue(nutrient.isRunning(on: day(10, 24), calendar: calendar), "isRunning knows nothing of schedules")

        nutrient.scheduleRaw = "20261019=week:2"
        XCTAssertTrue(nutrient.isDue(on: day(10, 22), weekDone: false, calendar: calendar))
        XCTAssertFalse(nutrient.isDue(on: day(10, 22), weekDone: true, calendar: calendar))

        nutrient.isRemoved = true
        XCTAssertFalse(nutrient.isDue(on: day(10, 22), calendar: calendar))
    }

    // MARK: Counting (phase 2a): History, streaks, the recap, analytics, reminders

    /// Mon, Wed, Fri from 1 Oct, in History: Tuesday is a rest day, logged or not.
    private func monWedFriLog(totals: [Date: [UUID: Double]], id: UUID, today: Date) -> HistoryLog {
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isRemoved: false, schedule: schedule("20261001=days:2,4,6"))
        return HistoryLog(nutrients: [nutrient], totals: totals, today: today, calendar: calendar)
    }

    func testHistoryRestDays() {
        let id = UUID()
        let log = monWedFriLog(totals: [day(10, 19): [id: 1], day(10, 20): [id: 1], day(10, 21): [id: 1]], id: id,
                               today: day(10, 26))
        XCTAssertEqual(log.day(day(10, 19)).completion, .allMet)
        let tuesday = log.day(day(10, 20))
        XCTAssertTrue(tuesday.isRest)
        XCTAssertTrue(tuesday.goals.isEmpty)
        XCTAssertEqual(tuesday.otherLogged.map(\.nutrientID), [id], "an off-day log is kept, not counted")
        XCTAssertEqual(tuesday.completion, .rest)
        XCTAssertTrue(log.day(day(10, 22)).isRest)
        XCTAssertEqual(log.day(day(10, 22)).completion, .noEntries, "a rest day with nothing logged is plain")
        XCTAssertFalse(log.day(day(10, 23)).isRest)
        XCTAssertEqual(log.recentDays(limit: 7).map(\.date), [day(10, 21), day(10, 19)], "rest days aren't results")
    }

    /// A day whose nutrients were all excluded isn't a rest day: it still breaks a streak, as before.
    func testAnExcludedDayIsntARestDay() {
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isRemoved: false)
        let log = HistoryLog(nutrients: [nutrient], totals: [day(10, 20): [id: 1]],
                             exclusions: [day(10, 20): [id]], today: day(10, 26), calendar: calendar)
        XCTAssertFalse(log.day(day(10, 20)).isRest)
    }

    /// Every other day, logged on each dose day: the off days in between don't break the streak.
    func testTheStreakStepsOverRestDays() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
        let magnesium = Nutrient(name: "Magnesium", unit: "mg", step: 200, dailyTarget: 200, sortOrder: 0)
        magnesium.createdAt = daysAgo(12)
        magnesium.scheduleRaw = NutrientSchedule()
            .setting(.cycle(on: 1, off: 1, start: daysAgo(10)), from: daysAgo(12), calendar: cal).encode(calendar: cal)
        context.insert(magnesium)
        for n in [10, 8, 6, 4, 2] {
            context.insert(IntakeRecord(nutrient: magnesium, amount: 200, date: daysAgo(n).addingTimeInterval(9 * 3600)))
        }
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 5)
        XCTAssertEqual(StreakService.compute(context: context).best, 5)

        let missed = try context.fetch(FetchDescriptor<IntakeRecord>()).first { cal.isDate($0.date, inSameDayAs: daysAgo(4)) }
        context.delete(try XCTUnwrap(missed))
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 1, "a missed dose day still breaks it")
        XCTAssertEqual(StreakService.compute(context: context).best, 3)
    }

    /// A Mon / Wed / Fri week met in full is 3 of 3 full days, not 3 of 7.
    func testTheRecapCountsOnlyDueDays() {
        let id = UUID()
        let log = monWedFriLog(totals: [day(10, 19): [id: 1], day(10, 21): [id: 1], day(10, 23): [id: 1]], id: id,
                               today: day(10, 26))
        let recap = WeeklyRecap.build(log: log, names: [id: "Magnesium"], week: day(10, 19), streaksEnabled: true)
        XCTAssertEqual(recap.dayCount, 3)
        XCTAssertEqual(recap.fullDays, 3)
        XCTAssertEqual(RecapText(recap).ringValue, "3/3")
        XCTAssertTrue(RecapText(recap).summary.hasPrefix("You met every goal on all 3 days."))
        XCTAssertEqual(recap.streak?.now, 3, "the rest days in between don't break the recap's streak")
    }

    func testAnalyticsTrackOnlyDoseDays() {
        let goal = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)
        let monWedFri = schedule("20261001=days:2,4,6")
        let summary = AnalyticsSummary(dayCount: 8, totals: [day(10, 19): 1, day(10, 21): 1], goal: goal,
                                       createdAt: day(10, 1), schedule: monWedFri, today: day(10, 26),
                                       calendar: calendar)
        XCTAssertEqual(summary.countedDays, 3, "Mon 19, Wed 21 and Fri 23; Monday 26 is today, not counted yet")
        XCTAssertEqual(summary.metDays, 2)

        // Created with the schedule: before 1 Oct every day would count, Tuesdays included.
        let pattern = WeekdayPattern(totals: [:], goal: goal, createdAt: day(10, 1), schedule: monWedFri,
                                     today: day(10, 26), calendar: calendar)
        let rates = Dictionary(uniqueKeysWithValues: pattern.entries.map { ($0.weekday, $0.hitRate) })
        XCTAssertNotNil(rates[2] ?? nil, "Monday is rated")
        XCTAssertNil(rates[3] ?? nil, "Tuesday has no dose days, so its square is blank")
    }

    func testRemindersOnlyOnDoseDays() {
        let plan = ReminderSchedule.Plan(nutrientID: UUID(), times: [.init(hour: 9, minute: 0)], loggedToday: false,
                                         schedule: schedule("20261001=days:2,4,6"))
        let occurrences = ReminderSchedule.occurrences(for: [plan], now: day(10, 19, hour: 7), calendar: calendar)
        XCTAssertEqual(occurrences.prefix(4).map(\.fireDate),
                       [day(10, 19, hour: 9), day(10, 21, hour: 9), day(10, 23, hour: 9), day(10, 26, hour: 9)])
    }
}
