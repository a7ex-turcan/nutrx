import XCTest
@testable import nutrx

/// The words around a dose plan (#135, docs/pro/DOSE-PLANS.md §4–5): the form's row, Today's step line, the analytics
/// header, the sheet's sentence, the goal card, Duration and Remove plan.
final class DosePlanTextTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var text: DosePlanText {
        DosePlanText(goalType: .minimum, unit: "mg", calendar: calendar, locale: Locale(identifier: "en_GB"))
    }

    /// The words with their dates' no-break spaces as ordinary ones, to compare.
    private func plain(_ words: String?) -> String? {
        words?.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func steps(_ goals: [Double], days: Int) -> [NutrientDosePlan.Step] {
        goals.map { NutrientDosePlan.Step(goal: NutrientGoal(target: $0), days: days) }
    }

    /// 200 mg from Tue 10 Nov for 7 days (to Mon 16), then 400 mg for 14 (Tue 17 to Mon 30).
    private func plan(_ end: NutrientDosePlan.End = .keep) -> NutrientDosePlan.Plan {
        NutrientDosePlan.Plan(start: day(11, 10), steps: [.init(goal: NutrientGoal(target: 200), days: 7),
                                                          .init(goal: NutrientGoal(target: 400), days: 14)],
                              end: end, appliesFrom: day(11, 10))
    }

    private func stored(_ end: NutrientDosePlan.End = .keep) -> NutrientDosePlan {
        NutrientDosePlan().creating(steps: plan(end).steps, end: end, start: day(11, 10), base: NutrientGoal(target: 100),
                                    today: day(11, 10), calendar: calendar)
    }

    func testTheFormsRow() {
        XCTAssertEqual(plain(text.summary(nil, today: day(11, 9))), "None")
        XCTAssertEqual(plain(text.summary(plan(), today: day(11, 9))), "200 → 400 mg · from Tue 10 Nov")
        XCTAssertEqual(plain(text.summary(plan(), today: day(11, 12, hour: 9))), "200 → 400 mg · step 1 of 2")
        XCTAssertEqual(plain(text.summary(plan(), today: day(11, 30))), "200 → 400 mg · step 2 of 2")
        XCTAssertEqual(plain(text.summary(plan(), today: day(12, 5))), "400 mg · plan kept")
        XCTAssertEqual(plain(text.summary(plan(.stop), today: day(12, 5))), "Ended 30 Nov")
        var held = plan()
        held.heldFrom = day(11, 12)
        XCTAssertEqual(plain(text.summary(held, today: day(11, 14))), "Paused")
    }

    func testTodaysLine() {
        XCTAssertNil(plain(text.todayLine(stored(), today: day(11, 9))?.text), "not started")
        XCTAssertEqual(plain(text.todayLine(stored(), today: day(11, 12))?.text), "Step 1 of 2 · until Mon")
        XCTAssertEqual(plain(text.todayLine(stored(), today: day(11, 16, hour: 20))?.text), "Step 1 of 2 · last day")
        XCTAssertEqual(plain(text.todayLine(stored(), today: day(11, 18))?.text), "Step 2 of 2 · until 30 Nov", "more than a week away")
        XCTAssertEqual(plain(text.todayLine(stored(), today: day(11, 30))?.text), "Step 2 of 2 · last day", "kept after it")
        XCTAssertNil(plain(text.todayLine(stored(), today: day(12, 5))?.text), "the last goal kept")
        XCTAssertNil(plain(text.todayLine(stored(.stop), today: day(11, 30))?.text), "the course's Last day says it")
        XCTAssertEqual(plain(text.todayLine(stored(.stop), today: day(11, 29))?.text), "Step 2 of 2 · until Mon")
        XCTAssertEqual(plain(text.todayLine(stored().holding(from: day(11, 12), calendar: calendar), today: day(11, 13))?.text),
                       "Plan paused")
    }

    func testTodaysLineShortens() {
        XCTAssertEqual(text.todayLine(stored(), today: day(11, 12)),
                       DosePlanText.TodayLine(text: "Step 1 of 2 · until Mon", shortText: "Step 1 of 2", compactText: "1 of 2"))
        XCTAssertEqual(text.todayLine(stored().holding(from: day(11, 12), calendar: calendar), today: day(11, 13)),
                       DosePlanText.TodayLine(text: "Plan paused"))
    }

    func testTheAnalyticsHeader() {
        XCTAssertEqual(plain(text.headerPart(stored(), today: day(11, 18))), "Step 2 of 2, until 30 Nov")
        XCTAssertNil(plain(text.headerPart(stored(), today: day(12, 5))))
        XCTAssertEqual(NutrientSummaryText.goalLine(goalType: .minimum, goalAmount: "400 mg",
                                                    planPart: "Step 2 of 2, until 30 Nov", groupName: "Morning stack"),
                       "At least 400 mg a day · Step 2 of 2, until 30 Nov · Morning stack")
    }

    func testTheSheetsSentence() {
        XCTAssertEqual(plain(text.sentence(plan(), today: day(11, 10))),
                       "200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and keeps 400 mg.")
        XCTAssertEqual(plain(text.sentence(plan(.stop), today: day(11, 10))),
                       "200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and stops after Mon 30 Nov.")
        XCTAssertEqual(plain(text.sentence(plan(), today: day(11, 7))),
                       "From Tue 10 Nov: 200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and keeps 400 mg.")
        let taper = NutrientDosePlan.Plan(start: day(11, 10), steps: steps([400, 300, 200], days: 7), end: .stop,
                                          appliesFrom: day(11, 10))
        XCTAssertEqual(plain(text.sentence(taper, today: day(11, 10))),
                       "400 mg until Mon 16 Nov, then 300 mg from Tue 17 Nov until Mon 23 Nov, then 200 mg from "
                       + "Tue 24 Nov, and stops after Mon 30 Nov.")
        XCTAssertEqual(plain(text.sentence(plan(), today: day(11, 10), courseEnd: day(11, 20))),
                       "200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and keeps 400 mg. "
                       + "Its course ends on Fri 20 Nov, so the plan stops there.")
        XCTAssertEqual(plain(text.sentence(plan(.stop), today: day(11, 10), courseEnd: day(12, 4))),
                       "200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and stops after Mon 30 Nov. "
                       + "This replaces the course's end on Fri 4 Dec.")
        XCTAssertEqual(plain(text.sentence(plan(), today: day(11, 10), courseEnd: day(12, 20))),
                       "200 mg until Mon 16 Nov, then 400 mg from Tue 17 Nov, and keeps 400 mg.",
                       "a course ending after the steps doesn't cut the plan short")
    }

    func testTheGoalCardAndDuration() {
        XCTAssertNil(plain(text.goalCard(plan(), today: day(11, 9))), "before the start, the goal card is as it was")
        XCTAssertEqual(plain(text.goalCard(plan(), today: day(11, 12))), "Set by your dose plan: 200 mg a day until Mon")
        XCTAssertEqual(plain(text.goalCard(plan(), today: day(12, 5))), "Set by your dose plan: 400 mg a day")
        XCTAssertEqual(plain(text.durationSummary(plan(.stop))), "Ends with the dose plan · Mon 30 Nov")
    }

    func testDatesDontBreakAcrossLines() {
        XCTAssertEqual(text.durationSummary(plan(.stop)), "Ends with the dose plan · Mon\u{00A0}30\u{00A0}Nov")
        XCTAssertEqual(plain(text.shortDurationSummary(plan(.stop))), "With the plan · Mon 30 Nov")
    }

    func testTheRowsShortForm() {
        XCTAssertNil(text.shortSummary(nil, today: day(11, 9)))
        XCTAssertEqual(plain(text.shortSummary(plan(), today: day(11, 9))), "From Tue 10 Nov")
        XCTAssertEqual(text.shortSummary(plan(), today: day(11, 12)), "Step 1 of 2")
        XCTAssertEqual(text.shortSummary(plan(), today: day(12, 5)), "Plan kept")
        XCTAssertNil(text.shortSummary(plan(.stop), today: day(12, 5)), "\"Ended 30 Nov\" is short already")
    }

    func testWithoutPro() {
        XCTAssertEqual(plain(text.pausedSince(day(11, 20))), "Paused without nutrx Pro since 20 Nov")
        XCTAssertEqual(text.heldSentence(NutrientGoal(target: 200)),
                       "It stays at 200 mg a day, then goes on where it left off when nutrx Pro is back.")
    }

    func testAmountsLengthsAndRemoving() {
        XCTAssertEqual(text.goals(steps([400, 300, 200, 100], days: 7)), "400 → 100 mg")
        XCTAssertEqual(text.goals(steps([400, 300, 200], days: 7)), "400 → 300 → 200 mg")
        let range = DosePlanText(goalType: .range, unit: "g", calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(range.goals([.init(goal: NutrientGoal(target: 120, upperBound: 160), days: 7),
                                    .init(goal: NutrientGoal(target: 140, upperBound: 180), days: 7)]),
                       "120–160 → 140–180 g")
        XCTAssertEqual(range.amount(NutrientGoal(target: 120, upperBound: 160)), "120–160 g")
        XCTAssertEqual(DosePlanText.length(days: 7, inWeeks: false), "for 7 days")
        XCTAssertEqual(DosePlanText.length(days: 1, inWeeks: false), "for 1 day")
        XCTAssertEqual(DosePlanText.length(days: 7, inWeeks: true), "for 1 week")
        XCTAssertEqual(DosePlanText.length(days: 14, inWeeks: true), "for 2 weeks")
        XCTAssertEqual(text.removeMessage(name: "Magnesium", goalFromToday: NutrientGoal(target: 400), endsWithPlan: false),
                       "Past days keep the goals they had. From today Magnesium's goal is 400 mg a day.")
        XCTAssertEqual(text.removeMessage(name: "Magnesium", goalFromToday: NutrientGoal(target: 300), endsWithPlan: true),
                       "Past days keep the goals they had. From today Magnesium's goal is 300 mg a day, with no end.")
    }
}
