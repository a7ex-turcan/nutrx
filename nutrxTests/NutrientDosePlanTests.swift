import SwiftData
import XCTest
@testable import nutrx

/// Dose plans (#135, docs/pro/DOSE-PLANS.md): each day's goal, the steps, keep or stop, edits and removal that leave
/// past days as they were, the Pro marker and the hold, and the stored form.
final class NutrientDosePlanTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private let base = NutrientGoal(target: 100)
    private let rampUp = [NutrientDosePlan.Step(goal: NutrientGoal(target: 200), days: 7),
                          NutrientDosePlan.Step(goal: NutrientGoal(target: 400), days: 14)]

    /// 200 for 7 days from 10 Nov (10–16), then 400 for 14 (17–30), created on 10 Nov.
    private func plan(end: NutrientDosePlan.End = .keep, start: Date? = nil) -> NutrientDosePlan {
        NutrientDosePlan().creating(steps: rampUp, end: end, start: start ?? day(11, 10), base: base,
                                    today: day(11, 10), calendar: calendar)
    }

    func testEachDaysGoal() {
        let plan = plan()
        XCTAssertEqual(plan.goal(on: day(11, 9), calendar: calendar), base, "before the start: pinned to the base goal")
        XCTAssertEqual(plan.goal(on: day(10, 1), calendar: calendar), base, "long before it too")
        XCTAssertEqual(plan.goal(on: day(11, 10, hour: 9), calendar: calendar)?.target, 200)
        XCTAssertEqual(plan.goal(on: day(11, 16), calendar: calendar)?.target, 200, "the first step's last day")
        XCTAssertEqual(plan.goal(on: day(11, 17), calendar: calendar)?.target, 400)
        XCTAssertEqual(plan.goal(on: day(12, 31), calendar: calendar)?.target, 400, "kept after the last step")
    }

    func testNoPlanIsTheBaseGoal() {
        XCTAssertNil(NutrientDosePlan().goal(on: day(11, 10), calendar: calendar))
        XCTAssertNil(NutrientDosePlan.decode("", calendar: calendar).goal(on: day(11, 10), calendar: calendar))
    }

    func testAStartInTheFuture() {
        let plan = plan(start: day(11, 20))
        XCTAssertNil(plan.goal(on: day(11, 15), calendar: calendar), "the base goal (nil) until it starts")
        XCTAssertEqual(plan.goal(on: day(11, 20), calendar: calendar)?.target, 200)
        XCTAssertTrue(plan.isMoving(on: day(11, 15), calendar: calendar), "not started yet still moves")
        XCTAssertNil(plan.position(on: day(11, 15), calendar: calendar))
    }

    func testPosition() {
        let plan = plan()
        XCTAssertEqual(plan.position(on: day(11, 12), calendar: calendar),
                       NutrientDosePlan.Position(step: 1, count: 2, lastDay: day(11, 16)))
        XCTAssertEqual(plan.position(on: day(11, 30), calendar: calendar),
                       NutrientDosePlan.Position(step: 2, count: 2, lastDay: day(11, 30)))
        XCTAssertNil(plan.position(on: day(12, 1), calendar: calendar), "settled on the kept goal")
    }

    func testAPlanThatStops() {
        let keep = plan(), stop = plan(end: .stop)
        XCTAssertNil(keep.stopDay(calendar: calendar))
        XCTAssertEqual(stop.stopDay(calendar: calendar), day(11, 30), "the last step's last day ends the course")
        XCTAssertFalse(stop.isMoving(on: day(12, 1), calendar: calendar), "finished")
    }

    func testARange() {
        let steps = [NutrientDosePlan.Step(goal: NutrientGoal(target: 120, upperBound: 160), days: 7),
                     NutrientDosePlan.Step(goal: NutrientGoal(target: 140, upperBound: 180), days: 7)]
        let plan = NutrientDosePlan().creating(steps: steps, end: .keep, start: day(11, 10),
                                               base: NutrientGoal(target: 100, upperBound: 150), today: day(11, 10),
                                               calendar: calendar)
        XCTAssertEqual(plan.goal(on: day(11, 18), calendar: calendar), NutrientGoal(target: 140, upperBound: 180))
        XCTAssertEqual(NutrientDosePlan.decode(plan.encode(calendar: calendar), calendar: calendar), plan)
    }

    // MARK: History isn't rewritten (§3)

    func testEditingAppliesFromToday() {
        let edited = plan().editing(steps: [rampUp[0], NutrientDosePlan.Step(goal: NutrientGoal(target: 300), days: 14)],
                                    end: .keep, today: day(11, 20), calendar: calendar)
        XCTAssertEqual(edited.goal(on: day(11, 12), calendar: calendar)?.target, 200, "the first step, as it was")
        XCTAssertEqual(edited.goal(on: day(11, 19), calendar: calendar)?.target, 400, "yesterday keeps 400")
        XCTAssertEqual(edited.goal(on: day(11, 20), calendar: calendar)?.target, 300, "300 from today")
        XCTAssertEqual(edited.goal(on: day(11, 9), calendar: calendar), base, "before the plan, still pinned")
    }

    func testRemovingKeepsThePastAndTheBaseReturns() {
        let removed = plan().removing(today: day(11, 20), calendar: calendar)
        XCTAssertNil(removed.newBase, "mid-plan, the base goal comes back as it is")
        XCTAssertNil(removed.plan.plan)
        XCTAssertEqual(removed.plan.goal(on: day(11, 12), calendar: calendar)?.target, 200)
        XCTAssertEqual(removed.plan.goal(on: day(11, 19), calendar: calendar)?.target, 400)
        XCTAssertEqual(removed.plan.goal(on: day(11, 9), calendar: calendar), base)
        XCTAssertNil(removed.plan.goal(on: day(11, 20), calendar: calendar), "the base goal from today")
    }

    func testRemovingAKeptPlanMakesItsGoalTheBase() {
        let removed = plan().removing(today: day(12, 5), calendar: calendar)
        XCTAssertEqual(removed.newBase?.target, 400, "nothing jumps")
        XCTAssertEqual(removed.plan.goal(on: day(11, 9), calendar: calendar), base,
                       "the days before the plan keep the old base: they're pinned")
    }

    func testChangingTheBaseLaterDoesntRejudgeThePast() {
        let removed = plan().removing(today: day(11, 20), calendar: calendar).plan
        let pinned = removed.pinningBase(base, today: day(11, 25), calendar: calendar)
        XCTAssertEqual(pinned.goal(on: day(11, 22), calendar: calendar), base, "the days since removal keep the old base")
        XCTAssertNil(pinned.goal(on: day(11, 25), calendar: calendar), "the new base from today")
        XCTAssertEqual(pinned.goal(on: day(11, 12), calendar: calendar)?.target, 200)
    }

    /// The base goal changing before a plan starts: the days since the plan was made keep the old base.
    func testChangingTheBaseBeforeThePlanStarts() {
        let waiting = plan(start: day(11, 20)).pinningBase(base, today: day(11, 15), calendar: calendar)
        XCTAssertEqual(waiting.goal(on: day(11, 12), calendar: calendar), base, "frozen with the old base")
        XCTAssertNil(waiting.goal(on: day(11, 16), calendar: calendar), "the new base from today until the start")
        XCTAssertEqual(waiting.goal(on: day(11, 20), calendar: calendar)?.target, 200, "the plan still starts")
    }

    func testANewPlanAfterAnOldOne() {
        let removed = plan().removing(today: day(11, 20), calendar: calendar).plan
        let again = removed.creating(steps: rampUp, end: .stop, start: day(12, 1), base: NutrientGoal(target: 150),
                                     today: day(11, 25), calendar: calendar)
        XCTAssertEqual(again.goal(on: day(11, 12), calendar: calendar)?.target, 200, "the first plan's days stay")
        XCTAssertEqual(again.goal(on: day(11, 22), calendar: calendar), NutrientGoal(target: 150),
                       "the days since its removal are pinned to the base they had")
        XCTAssertEqual(again.goal(on: day(12, 1), calendar: calendar)?.target, 200)
    }

    // MARK: Without Pro (§6)

    func testTheMarkerDecidesWhetherToHold() {
        let plan = plan()
        XCTAssertFalse(plan.canHold(on: day(11, 12), seenWithPro: day(11, 12), calendar: calendar), "seen today")
        XCTAssertFalse(plan.canHold(on: day(11, 12), seenWithPro: day(11, 11), calendar: calendar), "seen yesterday")
        XCTAssertTrue(plan.canHold(on: day(11, 12), seenWithPro: day(11, 10), calendar: calendar), "more than a day old")
        XCTAssertTrue(plan.canHold(on: day(11, 12), seenWithPro: nil, calendar: calendar), "never seen")
        XCTAssertFalse(plan.canHold(on: day(12, 5), seenWithPro: nil, calendar: calendar), "settled: nothing to hold")
        XCTAssertFalse(self.plan(end: .stop).canHold(on: day(12, 5), seenWithPro: nil, calendar: calendar),
                       "a finished plan never holds")
    }

    func testAHoldKeepsTheStepAndPastDays() {
        let held = plan().holding(from: day(11, 15), calendar: calendar)
        XCTAssertEqual(held.goal(on: day(11, 14), calendar: calendar)?.target, 200)
        XCTAssertEqual(held.goal(on: day(11, 25), calendar: calendar)?.target, 200, "the step waits")
        XCTAssertTrue(held.isHeld(on: day(11, 25), calendar: calendar))
        XCTAssertNil(held.position(on: day(11, 25), calendar: calendar), "paused: no step line")
        XCTAssertFalse(held.canHold(on: day(11, 25), seenWithPro: nil, calendar: calendar), "already held")
    }

    func testAHeldStopPlanDoesntStop() {
        XCTAssertNil(plan(end: .stop).holding(from: day(11, 15), calendar: calendar).stopDay(calendar: calendar))
    }

    func testResumingMovesTheRestLater() {
        let resumed = plan(end: .stop).holding(from: day(11, 15), calendar: calendar)
            .resuming(today: day(11, 25), calendar: calendar)
        XCTAssertFalse(resumed.isHeld(on: day(11, 25), calendar: calendar))
        XCTAssertEqual(resumed.goal(on: day(11, 24), calendar: calendar)?.target, 200, "the held days keep the held goal")
        XCTAssertEqual(resumed.goal(on: day(11, 26), calendar: calendar)?.target, 200,
                       "the step goes on where it held: two of its days were left")
        XCTAssertEqual(resumed.goal(on: day(11, 27), calendar: calendar)?.target, 400)
        XCTAssertEqual(resumed.stopDay(calendar: calendar), day(12, 10), "the stop day moves 10 days later")
    }

    func testResumingAPlanHeldBeforeItsStart() {
        let resumed = plan(start: day(11, 20)).holding(from: day(11, 15), calendar: calendar)
            .resuming(today: day(11, 18), calendar: calendar)
        XCTAssertNil(resumed.goal(on: day(11, 22), calendar: calendar), "the base goal: the start moved 3 days later")
        XCTAssertEqual(resumed.goal(on: day(11, 23), calendar: calendar)?.target, 200)
    }

    // MARK: Stored form

    func testRoundTrip() {
        for plan in [plan(), plan(end: .stop).holding(from: day(11, 15), calendar: calendar),
                     plan().removing(today: day(11, 20), calendar: calendar).plan] {
            XCTAssertEqual(NutrientDosePlan.decode(plan.encode(calendar: calendar), calendar: calendar), plan)
        }
        XCTAssertEqual(plan().encode(calendar: calendar), "h=*:100;p=20261110,20261110,keep|200x7,400x14")
    }

    func testADamagedFieldFallsBackToTheBaseGoal() {
        let damaged = NutrientDosePlan.decode("p=2026111,x,keep|200x7;h=zz", calendar: calendar)
        XCTAssertNil(damaged.plan)
        XCTAssertNil(damaged.goal(on: day(11, 12), calendar: calendar))
        XCTAssertNil(NutrientDosePlan.decode("p=20261110,20261110,keep|200x0", calendar: calendar).plan,
                     "a step of 0 days isn't read")
        XCTAssertEqual(NutrientDosePlan.decode("p=20261110,20261110,keep|200x120", calendar: calendar).plan?.steps.first?.days,
                       120, "a step a resume lengthened past 90 days still reads")
    }

    // MARK: The nutrient

    /// A plan starting today doesn't re-judge past days by its step: the streak counts them by the goal they had (the
    /// demo streak went from 10 to 11 days while past days took today's goal).
    func testAPlanStartingTodayDoesntChangeTheStreak() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)!.addingTimeInterval(9 * 3600) }
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        vitaminD.createdAt = daysAgo(5)
        context.insert(vitaminD)
        for n in [1, 2, 4, 5] { context.insert(IntakeRecord(nutrient: vitaminD, amount: 4000, date: daysAgo(n))) }
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 2000, date: daysAgo(3)))  // short of 4,000 that day
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 2)

        let steps = [NutrientDosePlan.Step(goal: NutrientGoal(target: 1000), days: 7),
                     NutrientDosePlan.Step(goal: NutrientGoal(target: 6000), days: 7)]
        vitaminD.dosePlanRaw = NutrientDosePlan().creating(steps: steps, end: .keep, start: today,
                                                           base: vitaminD.baseGoal, today: today).encode()
        try context.save()
        XCTAssertEqual(StreakService.compute(context: context).current, 2,
                       "three days ago still missed 4,000, though today's goal is 1,000")
    }

    func testTheNutrientsGoalOnADay() {
        let nutrient = Nutrient(name: "Magnesium", unit: "mg", step: 100, dailyTarget: 100, sortOrder: 0)
        XCTAssertEqual(nutrient.goal(on: day(11, 12), calendar: calendar), NutrientGoal(target: 100))
        nutrient.dosePlanRaw = plan().encode(calendar: calendar)
        XCTAssertEqual(nutrient.goal(on: day(11, 12), calendar: calendar).target, 200)
        XCTAssertEqual(nutrient.goal(on: day(11, 9), calendar: calendar).target, 100)
        XCTAssertEqual(GoalProgress(nutrient: nutrient, current: 250, on: day(11, 12)).countsAsMet,
                       GoalProgress(current: 250, goalType: .minimum, target: 200).countsAsMet)
    }

    // MARK: - The form's Save (#135 phase 3)

    private func setup(_ steps: [NutrientDosePlan.Step]? = nil, end: NutrientDosePlan.End = .keep,
                       start: Date? = nil) -> NutrientDosePlan.Plan {
        let first = start ?? day(11, 10)
        return NutrientDosePlan.Plan(start: first, steps: steps ?? rampUp, end: end, appliesFrom: first)
    }

    func testSavingANewPlanCreatesIt() {
        let saved = NutrientDosePlan().applying(setup(), oldBase: base, newBase: base, today: day(11, 10), calendar: calendar)
        XCTAssertNil(saved.newBase)
        XCTAssertEqual(saved.plan.goal(on: day(11, 12), calendar: calendar)?.target, 200)
        XCTAssertEqual(saved.plan.goal(on: day(11, 9), calendar: calendar), base, "the days before pinned")
    }

    func testSavingAnUnchangedPlanChangesNothing() {
        let current = plan()
        let saved = current.applying(current.plan, oldBase: base, newBase: base, today: day(11, 20), calendar: calendar)
        XCTAssertEqual(saved.plan, current)
    }

    func testSavingNewStepsAppliesFromToday() {
        let edited = setup([.init(goal: NutrientGoal(target: 200), days: 7), .init(goal: NutrientGoal(target: 600), days: 14)])
        let saved = plan().applying(edited, oldBase: base, newBase: base, today: day(11, 20), calendar: calendar)
        XCTAssertEqual(saved.plan.goal(on: day(11, 19), calendar: calendar)?.target, 400, "yesterday keeps its goal")
        XCTAssertEqual(saved.plan.goal(on: day(11, 20), calendar: calendar)?.target, 600)
    }

    func testSavingWithoutAKeptPlanMakesItsGoalTheBase() {
        let saved = plan().applying(nil, oldBase: base, newBase: base, today: day(12, 5), calendar: calendar)
        XCTAssertEqual(saved.newBase, NutrientGoal(target: 400))
        XCTAssertNil(saved.plan.plan)
        XCTAssertEqual(saved.plan.goal(on: day(11, 12), calendar: calendar)?.target, 200, "past days keep their goals")
        XCTAssertNil(plan().applying(nil, oldBase: base, newBase: base, today: day(11, 12), calendar: calendar).newBase,
                     "mid-step: the base goal is back")
    }

    func testANewBaseGoalAfterAPlanLeavesThePastAlone() {
        let removed = plan().applying(nil, oldBase: base, newBase: base, today: day(12, 5), calendar: calendar).plan
        let rebased = removed.applying(nil, oldBase: NutrientGoal(target: 400), newBase: NutrientGoal(target: 500),
                                       today: day(12, 10), calendar: calendar).plan
        XCTAssertEqual(rebased.goal(on: day(12, 7), calendar: calendar)?.target, 400, "judged by the old base")
        XCTAssertNil(rebased.goal(on: day(12, 10), calendar: calendar), "from today, the new base")
    }

    func testAPlanThatHasntStartedTakesANewStart() {
        let current = NutrientDosePlan().creating(steps: rampUp, end: .keep, start: day(11, 10), base: base,
                                                  today: day(11, 7), calendar: calendar)
        let saved = current.applying(setup(start: day(11, 12)), oldBase: base, newBase: base, today: day(11, 8),
                                     calendar: calendar).plan
        XCTAssertNil(saved.goal(on: day(11, 10), calendar: calendar), "the old start: the base goal")
        XCTAssertEqual(saved.goal(on: day(11, 12), calendar: calendar)?.target, 200)
        XCTAssertEqual(saved.plan?.start, day(11, 12))
    }
}
