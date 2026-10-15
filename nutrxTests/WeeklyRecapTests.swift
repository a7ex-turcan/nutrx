import XCTest
@testable import nutrx

/// The weekly recap's facts, words and checked rewording, over fixed weeks (Monday 5 – Sunday 11 October 2026).
final class WeeklyRecapTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private let vitaminD = UUID()
    private let omega = UUID()
    private let caffeine = UUID()

    private func day(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var nutrients: [HistoryNutrient] {
        [
            HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil, createdAt: day(9, 1), isDeleted: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 1000, upperBound: nil, createdAt: day(9, 1), isDeleted: false),
            HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil, createdAt: day(9, 1), isDeleted: false),
        ]
    }

    private var names: [UUID: String] { [vitaminD: "Vitamin D", omega: "Omega-3", caffeine: "Caffeine"] }

    /// Every goal met each day from `from` through `to` (October), except what `overrides` changes.
    private func totals(from: Date, through: Date, overrides: [Date: [UUID: Double]] = [:]) -> [Date: [UUID: Double]] {
        var totals: [Date: [UUID: Double]] = [:]
        var date = from
        while date <= through {
            totals[date] = [vitaminD: 4000, omega: 1000, caffeine: 200].merging(overrides[date] ?? [:]) { $1 }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return totals
    }

    /// The design's week: Vitamin D every day, Omega-3 missed on the weekend, Caffeine over on Monday.
    private var designWeek: [Date: [UUID: Double]] {
        totals(from: day(10, 5), through: day(10, 11),
               overrides: [day(10, 5): [caffeine: 500], day(10, 10): [omega: 0], day(10, 11): [omega: 0]])
    }

    private func recap(_ totals: [Date: [UUID: Double]], today: Date, streaks: Bool = true,
                       week: Date? = nil) -> WeeklyRecap {
        let log = HistoryLog(nutrients: nutrients, totals: totals, today: today, calendar: calendar)
        return WeeklyRecap.build(log: log, names: names, week: week ?? day(10, 5), streaksEnabled: streaks)
    }

    // MARK: - Facts

    func testTheDesignsWeek() {
        let recap = recap(designWeek, today: day(10, 12))
        XCTAssertEqual(recap.weekStart, day(10, 5))
        XCTAssertEqual(recap.goalsCounted, 21)
        XCTAssertEqual(recap.goalsMet, 18)
        XCTAssertEqual(recap.fullDayFlags, [false, true, true, true, true, false, false])
        XCTAssertEqual(recap.steadiest?.name, "Vitamin D")
        XCTAssertEqual(recap.slipped?.name, "Omega-3", "5 of 7 is below Caffeine's 6 of 7")
        XCTAssertEqual(recap.slipped?.missedDays, [day(10, 10), day(10, 11)])
        XCTAssertEqual(recap.overLimit?.name, "Caffeine")
        XCTAssertEqual(recap.overLimit?.overLimitDays, [day(10, 5)])
        XCTAssertNil(recap.streak, "no streak either Sunday")

        let text = RecapText(recap, calendar: calendar)
        XCTAssertEqual(text.summary, "You hit Vitamin D 7 of 7 days. Omega-3 slipped on the weekend. "
                       + "Caffeine went over your limit on Monday.")
        XCTAssertEqual(text.headline, "18 of 21 goals met")
        XCTAssertEqual(text.ringValue, "4/7")
        XCTAssertEqual(text.range, "5 – 11 October")
        XCTAssertEqual(text.cards.map(\.label), ["Steadiest", "Slipped"])
        XCTAssertEqual(text.cards[1].detail, "Missed Sat and Sun")
        XCTAssertEqual(text.todayLine, RecapText.together("**18** of 21 goals") + " · " + RecapText.together("Vitamin D steadiest"))
        XCTAssertEqual(text.historyLine, "Latest: " + RecapText.together("5 – 11 October") + " · " + RecapText.together("18 of 21 goals"))
        XCTAssertEqual(text.notificationBody, "You hit 18 of 21 goals. Vitamin D was your steadiest.")
    }

    func testADayWithNothingLoggedMeetsNothing() {
        // Thursday has no entries: even the "at most" Caffeine doesn't count as met.
        var week = totals(from: day(10, 5), through: day(10, 11))
        week[day(10, 8)] = nil
        let recap = recap(week, today: day(10, 12))
        XCTAssertEqual(recap.goalsMet, 18)
        XCTAssertEqual(recap.daysLogged, 6)
        XCTAssertFalse(recap.fullDayFlags[3])
    }

    func testAWeekStillRunningCountsCompletedDaysOnly() {
        // Wednesday morning: Monday and Tuesday count; today isn't over, so it can't be missed yet.
        let recap = recap(totals(from: day(10, 5), through: day(10, 7)), today: day(10, 7))
        XCTAssertEqual(recap.lastDay, day(10, 6))
        XCTAssertEqual(recap.goalsCounted, 6)
        XCTAssertEqual(recap.daysLogged, 2)
        XCTAssertEqual(recap.daysLoggedSoFar, 3, "today's logging shows in the first-week state")
        XCTAssertEqual(recap.fullDayFlags, [true, true, false, false, false, false, false])
    }

    func testOnTheRecapsSundayTheUnfinishedDayIsLeftOut() {
        // Sunday 18:00, with the evening Omega-3 not logged yet, and one earlier Sunday missed.
        let all = totals(from: day(9, 13), through: day(10, 11),
                         overrides: [day(9, 27): [omega: 0], day(10, 11): [omega: 0]])
        let recap = recap(all, today: day(10, 11))
        XCTAssertEqual(recap.lastDay, day(10, 10))
        XCTAssertEqual(recap.goalsCounted, 18, "Monday to Saturday")
        XCTAssertNil(recap.slipped, "Omega-3 hasn't slipped: Sunday isn't over")
        XCTAssertNil(recap.weakestWeekday, "one missed Sunday isn't a pattern")
    }

    func testStreakChange() {
        // Full days from 28 September, a miss on Friday 9 October, then full again.
        let all = totals(from: day(9, 28), through: day(10, 11), overrides: [day(10, 9): [omega: 0]])
        let recap = recap(all, today: day(10, 12))
        XCTAssertEqual(recap.streak, WeeklyRecap.StreakChange(now: 2, previous: 7))
        let text = RecapText(recap, calendar: calendar)
        XCTAssertTrue(text.summary.hasSuffix("Your streak stood at 2 days."))
        XCTAssertEqual(text.cards.last?.detail, "Down from 7 last Sunday")
        XCTAssertNil(self.recap(all, today: day(10, 12), streaks: false).streak, "Streaks turned off")
    }

    func testStreakDetails() {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        XCTAssertEqual(text.streakDetail(.init(now: 10, previous: 3)), "Up from 3 last Sunday")
        XCTAssertEqual(text.streakDetail(.init(now: 4, previous: 0)), "Started this week")
        XCTAssertEqual(text.streakDetail(.init(now: 0, previous: 5)), "Ended this week, after 5 days")
        XCTAssertEqual(text.streakDetail(.init(now: 7, previous: 7)), "Same as last Sunday")
    }

    func testTheWeekdayYouTendToMiss() {
        // Four weeks; Omega-3 missed on three of the Sundays.
        let all = totals(from: day(9, 14), through: day(10, 11),
                         overrides: [day(9, 20): [omega: 0], day(9, 27): [omega: 0], day(10, 11): [omega: 0]])
        let recap = recap(all, today: day(10, 12))
        XCTAssertEqual(recap.weakestWeekday, WeeklyRecap.WeekdayMiss(weekday: 1, missed: 3, weeks: 4))
        let card = RecapText(recap, calendar: calendar).cards.first { $0.kind == .weekday }
        XCTAssertEqual(card?.value, "Sunday")
        XCTAssertEqual(card?.detail, "3 of the last 4 weeks")
    }

    func testNoWeekdayStandsOutWithoutARepeat() {
        let all = totals(from: day(9, 14), through: day(10, 11),
                         overrides: [day(9, 20): [omega: 0], day(9, 22): [omega: 0]])
        XCTAssertNil(recap(all, today: day(10, 12)).weakestWeekday)
    }

    func testAPerfectWeek() {
        let all = totals(from: day(10, 5), through: day(10, 11))
        let text = RecapText(recap(all, today: day(10, 12)), calendar: calendar)
        XCTAssertEqual(text.summary, "You met every goal on all 7 days. Your streak stood at 7 days.")
        let running = RecapText(recap(totals(from: day(10, 5), through: day(10, 7)), today: day(10, 7)), calendar: calendar)
        XCTAssertEqual(running.summary, "You met every goal on both days. Your streak stood at 2 days.")
        // The first nutrient added on Wednesday: five days with goals, not "all 7".
        let late = totals(from: day(10, 7), through: day(10, 11))
        let log = HistoryLog(nutrients: nutrients.map {
            HistoryNutrient(id: $0.id, goalType: $0.goalType, target: $0.target, upperBound: $0.upperBound,
                            createdAt: day(10, 7), isDeleted: false)
        }, totals: late, today: day(10, 12), calendar: calendar)
        let lateRecap = WeeklyRecap.build(log: log, names: names, week: day(10, 5), streaksEnabled: false)
        XCTAssertEqual(RecapText(lateRecap, calendar: calendar).summary, "You met every goal on all 5 days.")
    }

    func testSeveralNutrientsEveryDay() {
        // Vitamin D and Caffeine every day; Omega-3 missed on Wednesday.
        let all = totals(from: day(10, 5), through: day(10, 11), overrides: [day(10, 7): [omega: 0]])
        let text = RecapText(recap(all, today: day(10, 12)), calendar: calendar)
        XCTAssertEqual(text.summary, "You hit Vitamin D and Caffeine every day. Omega-3 slipped on Wednesday. "
                       + "Your streak stood at 4 days.")
    }

    func testNothingMetSaysSo() {
        let none = totals(from: day(10, 5), through: day(10, 11)).mapValues { _ in [omega: 0.0, vitaminD: 0.0, caffeine: 900.0] }
        let text = RecapText(recap(none, today: day(10, 12)), calendar: calendar)
        XCTAssertTrue(text.summary.hasPrefix("No goals were met this week."))
        XCTAssertNil(text.recap.steadiest)
        XCTAssertEqual(text.notificationBody, "You hit 0 of 21 goals.")
    }

    // MARK: - Weeks

    func testWeeksRunMondayToSundayAndArriveSundayEvening() {
        // en_US starts weeks on Sunday; the recap still runs Monday to Sunday.
        XCTAssertEqual(WeeklyRecap.weekStart(containing: day(10, 11, hour: 20), calendar: calendar), day(10, 5))
        XCTAssertEqual(WeeklyRecap.weekStart(containing: day(10, 5), calendar: calendar), day(10, 5))
        XCTAssertEqual(WeeklyRecap.latestWeek(at: day(10, 11, hour: 17), calendar: calendar), day(9, 28))
        XCTAssertEqual(WeeklyRecap.latestWeek(at: day(10, 11, hour: 18), calendar: calendar), day(10, 5))
        XCTAssertEqual(WeeklyRecap.latestWeek(at: day(10, 13), calendar: calendar), day(10, 5))
    }

    func testRangeAcrossMonths() {
        let recap = recap(totals(from: day(9, 28), through: day(10, 4)), today: day(10, 5), week: day(9, 30))
        XCTAssertEqual(RecapText(recap, calendar: calendar).range, "28 September – 4 October")
    }

    func testDayLists() {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        XCTAssertEqual(text.when([day(10, 6), day(10, 8)]), "on Tuesday and Thursday")
        XCTAssertEqual(text.when([day(10, 5), day(10, 6), day(10, 7), day(10, 8)]), "on 4 days")
        XCTAssertEqual(text.dayList([day(10, 5), day(10, 7), day(10, 9)], short: true), "Mon, Wed and Fri")
        XCTAssertEqual(RecapText.firstBody(daysLogged: 3),
                       "You've logged 3 days so far. Sunday's recap will cover the whole week.")
        XCTAssertEqual(RecapText.firstBody(daysLogged: 1),
                       "You've logged 1 day so far. Sunday's recap will cover the whole week.")
    }

    // MARK: - Notification and Today card

    func testTheRecapNotification() {
        // Wednesday: the coming Sunday's notification, without numbers that would be stale by then.
        let midweek = recap(totals(from: day(10, 5), through: day(10, 7)), today: day(10, 7))
        let plan = RecapSchedule.plan(recap: midweek, now: day(10, 7, hour: 9), calendar: calendar)
        XCTAssertEqual(plan?.fireDate, day(10, 11, hour: 18))
        XCTAssertEqual(plan?.identifier, "weekly-recap-20261005")
        XCTAssertEqual(plan?.body, RecapText.notificationBodyWithoutFacts)
        // On the Sunday itself: the week's numbers (Monday to Saturday).
        let sunday = recap(designWeek, today: day(10, 11))
        XCTAssertEqual(RecapSchedule.plan(recap: sunday, now: day(10, 11, hour: 9), calendar: calendar)?.body,
                       RecapText(sunday, calendar: calendar).notificationBody)
        // Past 18:00 there's nothing left to schedule for that week; a quiet week gets none.
        XCTAssertNil(RecapSchedule.plan(recap: sunday, now: day(10, 11, hour: 19), calendar: calendar))
        let quiet = recap([:], today: day(10, 7))
        XCTAssertNil(RecapSchedule.plan(recap: quiet, now: day(10, 7, hour: 9), calendar: calendar))
    }

    func testWhichWeekTheNotificationIsFor() {
        XCTAssertEqual(RecapSchedule.upcomingWeek(at: day(10, 11, hour: 17), calendar: calendar), day(10, 5))
        XCTAssertEqual(RecapSchedule.upcomingWeek(at: day(10, 11, hour: 18), calendar: calendar), day(10, 12))
    }

    func testTodayShowsYourWeekFromSundayEveningThroughMonday() {
        let week = day(10, 5)
        XCTAssertFalse(RecapSchedule.showsTodayCard(forWeekStarting: week, at: day(10, 11, hour: 17), calendar: calendar))
        XCTAssertTrue(RecapSchedule.showsTodayCard(forWeekStarting: week, at: day(10, 11, hour: 18), calendar: calendar))
        XCTAssertTrue(RecapSchedule.showsTodayCard(forWeekStarting: week, at: day(10, 12, hour: 23), calendar: calendar))
        XCTAssertFalse(RecapSchedule.showsTodayCard(forWeekStarting: week, at: day(10, 13), calendar: calendar))
    }

    // MARK: - Rewording

    private struct StubModel: RecapPhrasing.Model {
        let text: String?
        func reword(_ facts: String) async throws -> String {
            guard let text else { throw CancellationError() }
            return text
        }
    }

    private func freshStore() -> UserDefaults {
        let name = "WeeklyRecapTests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    func testAGoodRewordingIsUsedAndKeptForTheWeek() async {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        let store = freshStore()
        let reworded = "Vitamin D was there all 7 days. Omega-3 dipped on the weekend, and Caffeine ran over on Monday."
        let first = await RecapPhrasing.summary(for: text, model: StubModel(text: reworded), store: store)
        XCTAssertEqual(first, reworded)
        let again = await RecapPhrasing.summary(for: text, model: StubModel(text: "Vitamin D, all 7 days, differently."),
                                                store: store)
        XCTAssertEqual(again, reworded, "the same facts keep the same words")
    }

    func testABadRewordingFallsBackToTheTemplate() async {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        let invented = "You hit Vitamin D 9 of 7 days."  // 9 isn't a fact
        let advice = "You hit Vitamin D 7 of 7 days. Try to take Omega-3 on weekends too."
        let unnamed = "A steady week with 7 good days."  // the steadiest nutrient isn't named
        for bad in [invented, advice, unnamed] {
            let summary = await RecapPhrasing.summary(for: text, model: StubModel(text: bad), store: freshStore())
            XCTAssertEqual(summary, text.summary, bad)
        }
        let failed = await RecapPhrasing.summary(for: text, model: StubModel(text: nil), store: freshStore())
        XCTAssertEqual(failed, text.summary, "a model error keeps the template")
        let none = await RecapPhrasing.summary(for: text, model: nil, store: freshStore())
        XCTAssertEqual(none, text.summary)
    }

    func testSpelledOutNumbersAreChecked() {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        XCTAssertFalse(RecapPhrasing.isAcceptable("You hit Vitamin D seven of nine days.", for: text), "nine isn't a fact")
        XCTAssertTrue(RecapPhrasing.isAcceptable("You hit Vitamin D seven of seven days.", for: text))
    }

    func testARejectedRewordingKeepsTheTemplateForTheWeek() async {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        let store = freshStore()
        let rejected = await RecapPhrasing.summary(for: text, model: StubModel(text: "Try harder, Vitamin D."), store: store)
        XCTAssertEqual(rejected, text.summary)
        let later = await RecapPhrasing.summary(for: text, model: StubModel(text: "Vitamin D held all 7 days."),
                                                store: store)
        XCTAssertEqual(later, text.summary, "the words don't change between opens")
    }

    func testNumbersInNamesAreFacts() {
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        XCTAssertTrue(text.factNumbers.contains(3), "the 3 of Omega-3")
        XCTAssertTrue(RecapPhrasing.isAcceptable("Vitamin D held all 7 days, and Omega-3 slipped at the weekend.", for: text))
    }

    /// The real on-device model, when this machine has Apple Intelligence (skipped otherwise, or when the simulator
    /// reports it available but can't load it).
    func testTheOnDeviceModelRewordsARecap() async throws {
        guard LabelExtractor.isModelAvailable else { throw XCTSkip("Apple Intelligence isn't available here") }
        let text = RecapText(recap(designWeek, today: day(10, 12)), calendar: calendar)
        guard let reworded = try? await FoundationRecapModel().reword(text.summary) else {
            throw XCTSkip("The model couldn't be loaded here")
        }
        // Whatever it says, what's shown is either an acceptable rewording or the template.
        let shown = await RecapPhrasing.summary(for: text, model: StubModel(text: reworded), store: freshStore())
        XCTAssertTrue(shown == text.summary || RecapPhrasing.isAcceptable(shown, for: text), shown)
    }
}
