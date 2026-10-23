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

        nutrient.isRemoved = true
        XCTAssertFalse(nutrient.isDue(on: day(10, 25), calendar: calendar))
    }

    /// Twice a week, met on Monday and Tuesday: due through Tuesday (it stays, Done, the day it's reached), then not
    /// until next Monday. Worked out from its own logs.
    func testAWeeklyNutrientIsDueUntilItsWeekIsDone() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let magnesium = Nutrient(name: "Magnesium", unit: "mg", step: 200, dailyTarget: 200, sortOrder: 0)
        magnesium.createdAt = day(10, 1)
        magnesium.scheduleRaw = "20261001=week:2"
        context.insert(magnesium)
        for date in [19, 20] {
            context.insert(IntakeRecord(nutrient: magnesium, amount: 200, date: day(10, date, hour: 9)))
        }
        try context.save()
        XCTAssertTrue(magnesium.isDue(on: day(10, 20), calendar: calendar))
        XCTAssertEqual(magnesium.weekProgress(including: day(10, 20), calendar: calendar),
                       NutrientSchedule.WeekProgress(met: 2, times: 2))
        XCTAssertFalse(magnesium.isDue(on: day(10, 21), calendar: calendar))
        XCTAssertFalse(magnesium.isDue(on: day(10, 25), calendar: calendar))
        XCTAssertEqual(magnesium.nextDueDay(after: day(10, 21), calendar: calendar), day(10, 26))
        XCTAssertTrue(magnesium.isDue(on: day(10, 26), calendar: calendar), "a new week")
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

    // MARK: Lists (phase 2b): Today, stacks, Siri

    /// A nutrient taken only on tomorrow's weekday is off today: in Not today, out of stacks, still found by Siri.
    func testTodayStacksAndSiriOnAnOffDay() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))  // Today's sections need it
        let weekly = Nutrient(name: "Vitamin D", unit: "IU", step: 50000, dailyTarget: 50000, sortOrder: 0)
        weekly.scheduleRaw = NutrientSchedule()
            .setting(.weekdays([cal.component(.weekday, from: tomorrow)]), from: today, calendar: cal)
            .encode(calendar: cal)
        let daily = Nutrient(name: "Magnesium", unit: "mg", step: 200, dailyTarget: 200, sortOrder: 1)
        context.insert(weekly)
        context.insert(daily)
        let stack = LogStack(name: "Morning", sortOrder: 0)
        context.insert(stack)
        _ = StackLogging.add(weekly, to: stack, context: context)
        _ = StackLogging.add(daily, to: stack, context: context)
        try context.save()

        let viewModel = TodayViewModel()
        viewModel.refresh(context: context)
        XCTAssertEqual(viewModel.groupSections.flatMap { $0.intakes.map(\.nutrient.name) }, ["Magnesium"])
        XCTAssertEqual(viewModel.notToday.map(\.nutrient.name), ["Vitamin D"])
        XCTAssertEqual(viewModel.notToday.first?.nextDue, tomorrow)
        XCTAssertEqual(viewModel.dayScore.total, 1, "an off-day nutrient isn't in the day score")
        XCTAssertTrue(viewModel.hasRunningNutrients)

        XCTAssertEqual(StackLogging.dueEntries(of: stack).compactMap(\.nutrient?.name), ["Magnesium"], "logging")
        XCTAssertEqual(StackLogging.activeEntries(of: stack).compactMap(\.nutrient?.name), ["Vitamin D", "Magnesium"],
                       "the stack editor and its picker still see it, so it can't be added twice")
        XCTAssertEqual(StackLogging.summary(of: stack), "Vitamin D, Magnesium")
        let logged = StackLogging.log(stack, context: context)
        XCTAssertEqual(logged.records.compactMap(\.nutrient?.name), ["Magnesium"])
        StackLogging.undo(logged, of: stack, context: context)
        let sundays = LogStack(name: "Sunday", sortOrder: 1)
        context.insert(sundays)
        _ = StackLogging.add(weekly, to: sundays, context: context)
        XCTAssertEqual(StackAccessibility.label(for: sundays, done: false), "Sunday: Vitamin D. Nothing due today.",
                       "VoiceOver hears why there's no Log")
        XCTAssertEqual(StackAccessibility.label(for: stack, done: true), "Morning: Vitamin D, Magnesium. Logged today.")
        XCTAssertEqual(NutrientEntityQuery.activeNutrients(in: context).map(\.name), ["Vitamin D", "Magnesium"],
                       "Siri still finds it")

        // Logged anyway: kept, shown in the log sheet's total, not counted.
        viewModel.addCustomAmount(50000, to: weekly, context: context)
        XCTAssertEqual(viewModel.total(for: weekly), 50000)
        XCTAssertEqual(viewModel.dayScore.total, 1)
    }

    /// Every nutrient off today: Today keeps its layout (not the empty state) and the score says so.
    func testADayWithNothingDue() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))
        let offToday = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 1000, sortOrder: 0)
        offToday.scheduleRaw = NutrientSchedule()
            .setting(.cycle(on: 1, off: 1, start: cal.date(byAdding: .day, value: 1, to: today)!), from: today,
                     calendar: cal)
            .encode(calendar: cal)
        context.insert(offToday)
        try context.save()

        let viewModel = TodayViewModel()
        viewModel.refresh(context: context)
        XCTAssertTrue(viewModel.groupSections.isEmpty)
        XCTAssertTrue(viewModel.hasRunningNutrients)
        XCTAssertEqual(viewModel.dayScore.title, "Nothing due today")
    }

    /// Off on its last day's next dose: its course is over before then.
    func testNextDueStopsAtTheCourse() {
        let nutrient = Nutrient(name: "Iron", unit: "mg", step: 18, dailyTarget: 18, sortOrder: 0)
        nutrient.scheduleRaw = "20261019=days:2"
        XCTAssertEqual(nutrient.nextDueDay(after: day(10, 21), calendar: calendar), day(10, 26))
        nutrient.endDate = day(10, 24)
        XCTAssertNil(nutrient.nextDueDay(after: day(10, 21), calendar: calendar))
    }

    func testNotTodayWording() {
        let text = ScheduleText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.next(day(10, 24), today: day(10, 23)), "Next: tomorrow")
        XCTAssertEqual(text.next(day(10, 25), today: day(10, 23)), "Next: Sunday")
        XCTAssertEqual(text.next(day(11, 2), today: day(10, 23)), "Next: Mon 2 Nov")
        XCTAssertEqual(text.next(nil, today: day(10, 23)), "Course ends first")
    }

    /// The log sheet's line when logging from Not today (#247).
    func testNotDueNote() {
        let text = ScheduleText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.notDueNote(nextDue: day(10, 25), isWeekDone: false, today: day(10, 23)),
                       "Not due today, so this won't count toward your goal. Next: Sunday.")
        XCTAssertEqual(text.notDueNote(nextDue: nil, isWeekDone: false, today: day(10, 23)),
                       "Not due again before its course ends, so this won't count toward your goal.")
        XCTAssertEqual(text.notDueNote(nextDue: day(10, 26), isWeekDone: true, today: day(10, 23)),
                       "Done this week, so this won't count toward your goal. Back Monday.")
        XCTAssertEqual(text.notDueNote(nextDue: nil, isWeekDone: true, today: day(10, 23)),
                       "Done this week, so this won't count toward your goal.")
    }

    // MARK: Setting a schedule (phase 3): the row, the sheet's footer, the draft

    func testSummary() {
        let text = ScheduleText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.summary(.everyDay), "Every day")
        XCTAssertEqual(text.summary(.weekdays([2, 4, 6])), "Mon, Wed, Fri")
        XCTAssertEqual(text.summary(.weekdays([2, 3, 4, 5, 6])), "Weekdays")
        XCTAssertEqual(text.summary(.weekdays([1, 7])), "Weekends")
        XCTAssertEqual(text.summary(.weekdays([1])), "Sundays")
        XCTAssertEqual(text.summary(.weekdays(Set(1...7))), "Every day")
        XCTAssertEqual(text.summary(.cycle(on: 1, off: 1, start: day(10, 19))), "Every other day")
        XCTAssertEqual(text.summary(.cycle(on: 1, off: 2, start: day(10, 19))), "Every 3 days")
        XCTAssertEqual(text.summary(.cycle(on: 5, off: 2, start: day(10, 19))), "5 days on, 2 off")
        XCTAssertEqual(text.summary(.cycle(on: 21, off: 7, start: day(10, 19))), "3 weeks on, 1 off")
        XCTAssertEqual(text.summary(.cycle(on: 7, off: 7, start: day(10, 19))), "1 week on, 1 off")
        XCTAssertEqual(text.summary(.weekly(times: 1)), "Once a week")
        XCTAssertEqual(text.summary(.weekly(times: 3)), "3 times a week")
    }

    /// Weekdays in the locale's order: Sunday first unless the calendar starts the week on Monday.
    func testWeekdaysInTheLocalesOrder() {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        XCTAssertEqual(ScheduleText(calendar: mondayFirst).ordered([1, 2, 7]), [2, 7, 1])
        XCTAssertEqual(ScheduleText(calendar: calendar).ordered([7, 2, 1]), [1, 2, 7])
        XCTAssertEqual(ScheduleText(calendar: mondayFirst, locale: Locale(identifier: "en_GB"))
                        .summary(.weekdays([1, 2])), "Mon, Sun")
    }

    func testUpcoming() {
        let text = ScheduleText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.upcoming(.weekdays([1]), today: day(10, 23)), "Next: Sun 25 Oct, then Sun 1 Nov.")
        XCTAssertEqual(text.upcoming(.weekdays([6, 1]), today: day(10, 23)), "Today, then Sun 25 Oct.")
        XCTAssertEqual(text.upcoming(.cycle(on: 1, off: 1, start: day(10, 24)), today: day(10, 23)),
                       "Next: Sat 24 Oct, then Mon 26 Oct.")
    }

    /// Adding a nutrient with a schedule sets it from today; editing it later keeps the days before.
    func testTheDraftSetsTheScheduleFromToday() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let draft = NutrientDraft()
        draft.name = "Iron"
        draft.unit = "mg"
        draft.step = "18"
        draft.dailyTarget = "18"
        draft.scheduleKind = .weekdays([2, 4, 6])
        let iron = try XCTUnwrap(draft.insertNutrient(into: context, group: nil, sortOrder: 0))
        XCTAssertEqual(iron.schedule().pieces, [NutrientSchedule.Piece(from: today, kind: .weekdays([2, 4, 6]))])

        let plain = NutrientDraft()
        plain.name = "Zinc"
        plain.unit = "mg"
        plain.step = "10"
        plain.dailyTarget = "10"
        XCTAssertEqual(plain.insertNutrient(into: context, group: nil, sortOrder: 1)?.scheduleRaw, "",
                       "every day stores nothing")

        // An earlier schedule stays for the days it covered.
        let lastWeek = cal.date(byAdding: .day, value: -7, to: today)!
        iron.scheduleRaw = NutrientSchedule().setting(.weekdays([1]), from: lastWeek, calendar: cal).encode(calendar: cal)
        let edit = NutrientDraft()
        edit.populate(from: iron)
        XCTAssertEqual(edit.scheduleKind, .weekdays([1]))
        let opened = edit.snapshot
        edit.scheduleKind = .everyDay
        XCTAssertNotEqual(edit.snapshot, opened, "a changed schedule is an unsaved change")
        edit.apply(to: iron)
        XCTAssertEqual(iron.schedule().pieces.map(\.kind), [.weekdays([1]), .everyDay])
        XCTAssertEqual(iron.schedule().kind(on: lastWeek), .weekdays([1]))
    }

    // MARK: Times a week (phase 4a): History, streaks, analytics

    /// Twice a week: the first two met days count; a third met day and an unmet logged day are rest days.
    func testHistoryCountsAWeeklyNutrientsFirstMetDays() {
        let id = UUID()
        let nutrient = HistoryNutrient(id: id, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                       isRemoved: false, schedule: schedule("20261001=week:2"))
        let log = HistoryLog(nutrients: [nutrient],
                             totals: [day(10, 19): [id: 1], day(10, 20): [id: 0.5], day(10, 21): [id: 1],
                                      day(10, 22): [id: 1]],
                             today: day(10, 26), calendar: calendar)
        XCTAssertEqual(log.day(day(10, 19)).completion, .allMet)
        XCTAssertTrue(log.day(day(10, 20)).isRest, "logged but not met: not a miss")
        XCTAssertEqual(log.day(day(10, 21)).goals.map(\.nutrientID), [id])
        XCTAssertTrue(log.day(day(10, 22)).isRest, "the week's count was already reached")
        XCTAssertEqual(log.day(day(10, 22)).otherLogged.map(\.nutrientID), [id])
        XCTAssertTrue(log.day(day(10, 23)).isRest, "an unlogged day of a weekly schedule isn't a miss")
    }

    /// A weekly-only setup: the streak counts exactly its counted days, stepping over the rest.
    func testTheStreakCountsAWeeklyNutrientsMetDays() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 50000, dailyTarget: 50000, sortOrder: 0)
        vitaminD.createdAt = daysAgo(20)
        vitaminD.scheduleRaw = NutrientSchedule().setting(.weekly(times: 3), from: daysAgo(20), calendar: cal)
            .encode(calendar: cal)
        context.insert(vitaminD)
        let metDays = (1...10).map(daysAgo)
        for day in metDays {
            context.insert(IntakeRecord(nutrient: vitaminD, amount: 50000, date: day.addingTimeInterval(9 * 3600)))
        }
        try context.save()
        let counted = vitaminD.schedule(calendar: cal).weeklyCountedDays(metDays, calendar: cal)
        XCTAssertEqual(StreakService.compute(context: context).current, counted.count)
        XCTAssertLessThan(counted.count, metDays.count, "only three a week count")
    }

    /// Twice a week over 30 days: five weeks end in the period; three reached their count.
    func testAnalyticsJudgeAWeeklyNutrientByWeeks() {
        let goal = AnalyticsGoal(goalType: .minimum, target: 1, upperBound: nil)
        let met: [Date] = [day(9, 21), day(9, 22),  // week to 27 Sep: met
                           day(10, 1),               // to 4 Oct: 1 of 2
                           day(10, 5), day(10, 9),   // to 11 Oct: met
                                                     // to 18 Oct: none
                           day(10, 19), day(10, 20), day(10, 21)]  // to 25 Oct: met (two count)
        let summary = AnalyticsSummary(dayCount: 30, totals: Dictionary(uniqueKeysWithValues: met.map { ($0, 1.0) }),
                                       goal: goal, createdAt: day(9, 1), schedule: schedule("20260901=week:2"),
                                       today: day(10, 26), calendar: calendar)
        XCTAssertEqual(summary.weeks, AnalyticsWeeks(met: 3, total: 5))
        XCTAssertEqual(summary.hitRate, 0.6)
        XCTAssertFalse(summary.days.first { $0.date == day(10, 21) }?.isTracked ?? true, "the week's third met day")
        let hitRate = AnalyticsStat.triplet(for: summary, period: .month, unit: "IU", goalType: .minimum,
                                            calendar: calendar, locale: Locale(identifier: "en_GB"))[0]
        XCTAssertEqual(hitRate.value, "60")
        XCTAssertEqual(hitRate.caption, "3 of 5 weeks")
        XCTAssertLessThan(summary.average ?? 1, 1, "a daily average over every covered day, not just met ones")

        // A daily nutrient keeps its hit rate by days.
        XCTAssertNil(AnalyticsSummary(dayCount: 30, totals: [:], goal: goal, createdAt: day(9, 1), today: day(10, 26),
                                      calendar: calendar).weeks)
    }

    /// The analytics screen loads the days before the period back to its first week's Monday, so a week met on Monday
    /// and Tuesday isn't read as missed when the period starts later that week.
    func testAnalyticsLoadTheFirstWeeksEarlierDays() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
        let iron = Nutrient(name: "Iron", unit: "mg", step: 18, dailyTarget: 18, sortOrder: 0)
        iron.createdAt = daysAgo(70)
        iron.scheduleRaw = NutrientSchedule().setting(.weekly(times: 2), from: daysAgo(70), calendar: cal)
            .encode(calendar: cal)
        context.insert(iron)
        for n in 1...60 where [2, 3].contains(cal.component(.weekday, from: daysAgo(n))) {  // Mondays, Tuesdays
            context.insert(IntakeRecord(nutrient: iron, amount: 18, date: daysAgo(n).addingTimeInterval(9 * 3600)))
        }
        try context.save()
        let viewModel = NutrientAnalyticsViewModel(nutrient: iron, modelContext: context)
        viewModel.selectedPeriod = .month
        let weeks = try XCTUnwrap(viewModel.summary?.weeks)
        XCTAssertGreaterThanOrEqual(weeks.total, 4)
        XCTAssertEqual(weeks.met, weeks.total, "every week was met on its Monday and Tuesday")
    }

    /// A met day in a course gap doesn't take one of the week's slots for the streak (as in History).
    func testTheStreakSkipsAWeeklyDayInACourseGap() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let lastMonday = cal.date(byAdding: .day, value: -7, to: NutrientSchedule.weekStart(of: today, calendar: cal))!
        let lastWednesday = cal.date(byAdding: .day, value: 2, to: lastMonday)!
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 50000, dailyTarget: 50000, sortOrder: 0)
        vitaminD.createdAt = cal.date(byAdding: .day, value: -30, to: today)!
        vitaminD.scheduleRaw = NutrientSchedule().setting(.weekly(times: 1), from: vitaminD.createdAt, calendar: cal)
            .encode(calendar: cal)
        vitaminD.courseGapsRaw = NutrientCourse.encode([lastMonday...lastMonday], calendar: cal)
        context.insert(vitaminD)
        for day in [lastMonday, lastWednesday] {
            context.insert(IntakeRecord(nutrient: vitaminD, amount: 50000, date: day.addingTimeInterval(9 * 3600)))
        }
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 1, "Wednesday counts; Monday was paused")
    }

    // MARK: Times a week (phase 4b): the weekly recap and the report

    /// A twice-a-week nutrient beside a daily one, for the week of 19–25 Oct (built on Monday 26).
    private func weeklyAndDailyLog(weeklyFrom: String = "20261001") -> (HistoryLog, weekly: UUID, daily: UUID) {
        let weeklyID = UUID(), dailyID = UUID()
        let nutrients = [
            HistoryNutrient(id: weeklyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                            isRemoved: false, schedule: schedule("\(weeklyFrom)=week:2")),
            HistoryNutrient(id: dailyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                            isRemoved: false),
        ]
        var totals: [Date: [UUID: Double]] = [:]
        for date in 19...25 { totals[day(10, date)] = [dailyID: 1] }
        for date in [19, 21, 22] { totals[day(10, date), default: [:]][weeklyID] = 1 }
        return (HistoryLog(nutrients: nutrients, totals: totals, today: day(10, 26), calendar: calendar), weeklyID, dailyID)
    }

    func testTheRecapJudgesAWeeklyNutrientByTheWeek() {
        let (log, weeklyID, dailyID) = weeklyAndDailyLog()
        let recap = WeeklyRecap.build(log: log, names: [weeklyID: "Vitamin D", dailyID: "Magnesium"], week: day(10, 19),
                                      streaksEnabled: false)
        XCTAssertEqual(recap.weekly, [WeeklyRecap.WeeklyGoal(id: weeklyID, name: "Vitamin D", met: 2, times: 2)])
        XCTAssertEqual(recap.nutrients.map(\.id), [dailyID], "not in the day-by-day picks, where it'd read 100 %")
        XCTAssertEqual(recap.steadiest?.id, dailyID)
        XCTAssertEqual(recap.goalsMet, 9, "7 Magnesium days and Vitamin D's 2 counted days")
        XCTAssertEqual(recap.goalsCounted, 9)
        XCTAssertTrue(RecapText(recap).summary.contains("Vitamin D: 2 of 2 this week."))
        XCTAssertTrue(RecapText(recap).factNumbers.isSuperset(of: [2]))
    }

    /// Set on Wednesday: the week isn't wholly under it, so it isn't judged.
    func testTheRecapLeavesOutAPartialWeek() {
        let (log, weeklyID, dailyID) = weeklyAndDailyLog(weeklyFrom: "20261021")
        let recap = WeeklyRecap.build(log: log, names: [weeklyID: "Vitamin D", dailyID: "Magnesium"], week: day(10, 19),
                                      streaksEnabled: false)
        XCTAssertTrue(recap.weekly.isEmpty)
        XCTAssertFalse(RecapText(recap).summary.contains("Vitamin D:"))
    }

    func testTheReportShowsWeeksMet() throws {
        let weeklyID = UUID()
        let nutrient = HistoryNutrient(id: weeklyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(9, 1),
                                       isRemoved: false, schedule: schedule("20260901=week:2"))
        let met = [day(9, 28), day(9, 30),  // week to 4 Oct: met
                   day(10, 5),              // to 11 Oct: 1 of 2
                   day(10, 12), day(10, 13), day(10, 14),  // to 18 Oct: met
                   day(10, 19), day(10, 25)]  // to 25 Oct: met
        let log = HistoryLog(nutrients: [nutrient],
                             totals: Dictionary(uniqueKeysWithValues: met.map { ($0, [weeklyID: 1.0]) }),
                             today: day(10, 26), calendar: calendar)
        let report = DoctorReport.build(log: log, names: [weeklyID: "Vitamin D"], units: [weeklyID: "IU"],
                                        start: day(9, 28), end: day(10, 25))
        let section = try XCTUnwrap(report.sections.first)
        XCTAssertEqual(section.weeks, AnalyticsWeeks(met: 3, total: 4))
        XCTAssertEqual(section.hitRate, 0.75)
        XCTAssertEqual(ReportText(report: report).weeksMet(AnalyticsWeeks(met: 3, total: 4)), "3 of 4")
        XCTAssertEqual(report.longestStreak, 7, "every counted day met; the rest days in between don't end the run")
        // The cover's summary table says it's weeks, and the goal says how often (#248).
        let text = ReportText(report: report)
        XCTAssertEqual(section.weeklyTimes, 2)
        XCTAssertEqual(text.summaryRate(section), "3 of 4 weeks")
        XCTAssertTrue(text.goal(section).hasSuffix(", 2 times a week"), text.goal(section))
        XCTAssertTrue(text.goalLine(section).hasPrefix("Goal: at least"), text.goalLine(section))
    }

    /// Every daily goal met but the weekly one short: not "every goal", and the weekly line says so.
    func testTheRecapIsntPerfectWhenAWeeklyGoalFellShort() {
        let weeklyID = UUID(), dailyID = UUID()
        let log = HistoryLog(
            nutrients: [
                HistoryNutrient(id: weeklyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                isRemoved: false, schedule: schedule("20261001=week:3")),
                HistoryNutrient(id: dailyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(10, 1),
                                isRemoved: false),
            ],
            totals: Dictionary(uniqueKeysWithValues: (19...25).map { date in
                (day(10, date), date == 20 ? [dailyID: 1, weeklyID: 1] : [dailyID: 1])
            }),
            today: day(10, 26), calendar: calendar)
        let recap = WeeklyRecap.build(log: log, names: [weeklyID: "Omega-3", dailyID: "Magnesium"], week: day(10, 19),
                                      streaksEnabled: false)
        let summary = RecapText(recap).summary
        XCTAssertFalse(summary.contains("every goal"), summary)
        XCTAssertTrue(summary.contains("Omega-3: 1 of 3 this week."), summary)
        XCTAssertTrue(RecapText(recap).factNumbers.contains(3), "the 3 in Omega-3 (and its count)")

        // A number that's only in a weekly nutrient's name: B12, twice a week.
        let b12 = WeeklyRecap.build(log: log, names: [weeklyID: "Vitamin B12", dailyID: "Magnesium"], week: day(10, 19),
                                    streaksEnabled: false)
        XCTAssertTrue(RecapText(b12).factNumbers.contains(12))
    }

    /// The report's longest run with only the weekly nutrient included: a daily one left out doesn't end the run on
    /// the weekly one's off days.
    func testTheReportsRunStepsOverDaysTheIncludedNutrientsDontCount() {
        let weeklyID = UUID(), dailyID = UUID()
        let log = HistoryLog(
            nutrients: [
                HistoryNutrient(id: weeklyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(9, 1),
                                isRemoved: false, schedule: schedule("20260901=week:2")),
                HistoryNutrient(id: dailyID, goalType: .minimum, target: 1, upperBound: nil, createdAt: day(9, 1),
                                isRemoved: false),
            ],
            totals: Dictionary(uniqueKeysWithValues: (12...25).map { date in
                (day(10, date), [12, 14, 19, 21].contains(date) ? [dailyID: 1, weeklyID: 1] : [dailyID: 1])
            }),
            today: day(10, 26), calendar: calendar)
        let report = DoctorReport.build(log: log, names: [weeklyID: "Iron"], units: [weeklyID: "mg"],
                                        start: day(10, 12), end: day(10, 25), nutrientIDs: [weeklyID])
        XCTAssertEqual(report.longestStreak, 4, "its four counted days, all met")
    }

    // MARK: Times a week (phase 4c): Today, reminders, the sheet

    /// Twice a week, nothing met yet this week: on Today with "0 of 2", outside the day score until met today.
    func testTodayCountsAWeeklyNutrientOnceMet() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))
        let iron = Nutrient(name: "Iron", unit: "mg", step: 18, dailyTarget: 18, sortOrder: 0)
        iron.createdAt = cal.date(byAdding: .day, value: -30, to: today)!
        iron.scheduleRaw = NutrientSchedule().setting(.weekly(times: 2), from: iron.createdAt, calendar: cal)
            .encode(calendar: cal)
        let zinc = Nutrient(name: "Zinc", unit: "mg", step: 10, dailyTarget: 10, sortOrder: 1)
        context.insert(iron)
        context.insert(zinc)
        try context.save()

        let viewModel = TodayViewModel()
        viewModel.refresh(context: context)
        let card = try XCTUnwrap(viewModel.groupSections.flatMap(\.intakes).first { $0.nutrient.name == "Iron" })
        XCTAssertEqual(card.weekly, NutrientSchedule.WeekProgress(met: 0, times: 2))
        XCTAssertFalse(card.isGoalToday, "the group chips count through this too")
        XCTAssertEqual(viewModel.dayScore.total, 1, "not a goal of the day until it's met")

        viewModel.addCustomAmount(18, to: iron, context: context)
        let logged = try XCTUnwrap(viewModel.groupSections.flatMap(\.intakes).first { $0.nutrient.name == "Iron" })
        XCTAssertEqual(logged.weekly, NutrientSchedule.WeekProgress(met: 1, times: 2))
        XCTAssertTrue(logged.isGoalToday)
        XCTAssertEqual(viewModel.dayScore.total, 2)
        XCTAssertEqual(viewModel.dayScore.met, 1)
    }

    /// Once a week, met yesterday (in the same week): Not today, done this week, back on Monday.
    func testAWeekDoneMovesToNotToday() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        try XCTSkipIf(NutrientSchedule.weekStart(of: today, calendar: cal) == today, "on a Monday there's no earlier day")
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 50000, dailyTarget: 50000, sortOrder: 0)
        vitaminD.createdAt = cal.date(byAdding: .day, value: -30, to: today)!
        vitaminD.scheduleRaw = NutrientSchedule().setting(.weekly(times: 1), from: vitaminD.createdAt, calendar: cal)
            .encode(calendar: cal)
        context.insert(vitaminD)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 50000, date: yesterday.addingTimeInterval(9 * 3600)))
        try context.save()

        let viewModel = TodayViewModel()
        viewModel.refresh(context: context)
        XCTAssertTrue(viewModel.groupSections.isEmpty)
        let item = try XCTUnwrap(viewModel.notToday.first)
        XCTAssertTrue(item.isWeekDone)
        XCTAssertEqual(item.nextDue, cal.date(byAdding: .day, value: 7, to: NutrientSchedule.weekStart(of: today, calendar: cal)))
        XCTAssertEqual(ScheduleText.doneThisWeek(nextDue: item.nextDue), "Done this week · back Monday")

        // A course whose last day is today is over before Monday.
        vitaminD.endDate = today
        try context.save()
        viewModel.refresh(context: context)
        let ending = try XCTUnwrap(viewModel.notToday.first)
        XCTAssertTrue(ending.isWeekDone)
        XCTAssertNil(ending.nextDue)
        XCTAssertEqual(ScheduleText.doneThisWeek(nextDue: ending.nextDue), "Done this week · course ends first")
    }

    /// A week whose count is reached has no more reminders that week; the next week's are there.
    func testRemindersStopForTheRestOfADoneWeek() {
        let plan = ReminderSchedule.Plan(nutrientID: UUID(), times: [.init(hour: 9, minute: 0)], loggedToday: true,
                                         schedule: schedule("20261001=week:2"), doneWeekStart: day(10, 19))
        let occurrences = ReminderSchedule.occurrences(for: [plan], now: day(10, 21, hour: 7), calendar: calendar)
        XCTAssertEqual(occurrences.first?.fireDate, day(10, 26, hour: 9))
    }

    func testTimesAWeekWording() {
        let text = ScheduleText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.upcoming(.weekly(times: 3), today: day(10, 23)), "Any 3 days a week, Monday to Sunday.")
        XCTAssertEqual(text.upcoming(.weekly(times: 1), today: day(10, 23)), "Any one day a week, Monday to Sunday.")
        XCTAssertEqual(ScheduleText.weekLine(.init(met: 2, times: 3)), "2 of 3 this week")
    }

    /// Times a week only fits an "At least" goal; with another the form can't be saved.
    func testTimesAWeekNeedsAnAtLeastGoal() {
        let draft = NutrientDraft()
        draft.name = "Caffeine"
        draft.unit = "mg"
        draft.step = "100"
        draft.dailyTarget = "400"
        draft.scheduleKind = .weekly(times: 3)
        XCTAssertNil(draft.scheduleError)
        XCTAssertTrue(draft.isValid)
        draft.goalType = .maximum
        XCTAssertNotNil(draft.scheduleError)
        XCTAssertFalse(draft.isValid)
    }
}
