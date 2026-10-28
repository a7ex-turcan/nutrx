import XCTest
@testable import nutrx

/// The monthly recap's facts (#136, docs/pro/RECAPS.md §2), over October 2026 (Thursday 1 – Saturday 31).
final class MonthlyRecapTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private let vitaminD = UUID()
    private let omega = UUID()
    private let caffeine = UUID()

    private func day(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var nutrients: [HistoryNutrient] {
        [
            HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil, createdAt: day(8, 1), isRemoved: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 1000, upperBound: nil, createdAt: day(8, 1), isRemoved: false),
            HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil, createdAt: day(8, 1), isRemoved: false),
        ]
    }

    private var names: [UUID: String] { [vitaminD: "Vitamin D", omega: "Omega-3", caffeine: "Caffeine"] }

    /// Every goal met each day from `from` through `through`, except what `overrides` changes.
    private func totals(from: Date, through: Date, overrides: [Date: [UUID: Double]] = [:]) -> [Date: [UUID: Double]] {
        var totals: [Date: [UUID: Double]] = [:]
        var date = from
        while date <= through {
            totals[date] = [vitaminD: 4000, omega: 1000, caffeine: 200].merging(overrides[date] ?? [:]) { $1 }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return totals
    }

    /// October: Omega-3 missed every Sunday (4, 11, 18, 25), Caffeine over on the 6th.
    private var october: [Date: [UUID: Double]] {
        var overrides: [Date: [UUID: Double]] = [day(10, 6): [caffeine: 500]]
        for sunday in [4, 11, 18, 25] { overrides[day(10, sunday)] = [omega: 0] }
        return totals(from: day(10, 1), through: day(10, 31), overrides: overrides)
    }

    private func recap(_ totals: [Date: [UUID: Double]], today: Date, streaks: Bool = true,
                       nutrients: [HistoryNutrient]? = nil) -> MonthlyRecap {
        let log = HistoryLog(nutrients: nutrients ?? self.nutrients, totals: totals, today: today, calendar: calendar)
        return MonthlyRecap.build(log: log, names: names, month: day(10, 15), streaksEnabled: streaks)
    }

    // MARK: - Facts

    func testAWholeMonth() {
        let recap = recap(october, today: day(11, 1))
        XCTAssertTrue(recap.isMonthOver)
        XCTAssertEqual(recap.monthStart, day(10, 1))
        XCTAssertEqual(recap.lastDay, day(10, 31))
        XCTAssertEqual(recap.daysElapsed, 31)
        XCTAssertEqual(recap.dayCount, 31)
        XCTAssertEqual(recap.daysLogged, 31)
        XCTAssertEqual(recap.goalsCounted, 93)
        XCTAssertEqual(recap.goalsMet, 88, "4 missed Omega-3 days and 1 day over the caffeine limit")
        XCTAssertEqual(recap.fullDays, 26)
        XCTAssertTrue(recap.hasData)
    }

    func testTheGridOutlinesOnlyDaysWithSomethingDue() {
        // Tracking starts on the 8th, and the month runs to the 15th: due days are the 8th to the 14th.
        let late = nutrients.map {
            HistoryNutrient(id: $0.id, goalType: $0.goalType, target: $0.target, upperBound: $0.upperBound,
                            createdAt: day(10, 8), isRemoved: false)
        }
        let recap = recap(totals(from: day(10, 8), through: day(10, 14)), today: day(10, 15), nutrients: late)
        XCTAssertEqual(recap.dueDayFlags.count, 31)
        XCTAssertEqual(recap.dueDayFlags.indices.filter { recap.dueDayFlags[$0] }, Array(7...13))
        XCTAssertEqual(recap.dayCount, 7)
    }

    func testTheMonthSoFarCountsOnlyFinishedDays() {
        let recap = recap(october, today: day(10, 15, hour: 9))
        XCTAssertFalse(recap.isMonthOver)
        XCTAssertEqual(recap.lastDay, day(10, 14))
        XCTAssertEqual(recap.daysElapsed, 14)
        XCTAssertEqual(recap.daysLoggedSoFar, 15, "today's logs count as logged, not as a result")
        XCTAssertEqual(recap.goalsCounted, 42)
    }

    func testPicks() {
        let recap = recap(october, today: day(11, 1))
        XCTAssertEqual(recap.steadiest?.name, "Vitamin D")
        XCTAssertEqual(recap.slipped?.name, "Omega-3")
        XCTAssertEqual(recap.slipped?.missedDays.count, 4)
        XCTAssertEqual(recap.overLimit?.name, "Caffeine")
    }

    func testTheWeekdayYouTendToMiss() {
        let miss = recap(october, today: day(11, 1)).weakestWeekday
        XCTAssertEqual(miss?.weekday, 1, "Sunday")
        XCTAssertEqual(miss?.missed, 4)
        XCTAssertEqual(miss?.weeks, 4)
    }

    func testNoWeekdayStandsOutWithOneMiss() {
        let totals = totals(from: day(10, 1), through: day(10, 31), overrides: [day(10, 4): [omega: 0]])
        XCTAssertNil(recap(totals, today: day(11, 1)).weakestWeekday)
    }

    func testBestStreakInsideTheMonth() {
        // Full days 1–3 and 5–10 (6 days), then 12–31 (20 days): Sundays 4 and 11 missed only.
        let totals = totals(from: day(10, 1), through: day(10, 31),
                            overrides: [day(10, 4): [omega: 0], day(10, 11): [omega: 0]])
        XCTAssertEqual(recap(totals, today: day(11, 1)).bestStreak, 20)
        XCTAssertNil(recap(totals, today: day(11, 1), streaks: false).bestStreak)
    }

    func testABestStreakOfOneIsLeftOut() {
        var overrides: [Date: [UUID: Double]] = [:]
        for date in stride(from: 2, through: 31, by: 2) { overrides[day(10, date)] = [omega: 0] }
        let totals = totals(from: day(10, 1), through: day(10, 31), overrides: overrides)
        XCTAssertNil(recap(totals, today: day(11, 1)).bestStreak)
    }

    // MARK: - Against last month

    func testComparedWithLastMonth() {
        // September: Omega-3 missed every day (2 of 3 goals) → 67 %; October 88 of 93 → 95 %.
        var septemberOverrides: [Date: [UUID: Double]] = [:]
        for date in 1...30 { septemberOverrides[day(9, date)] = [omega: 0] }
        let all = totals(from: day(9, 1), through: day(9, 30), overrides: septemberOverrides)
            .merging(october) { $1 }
        let comparison = recap(all, today: day(11, 1)).comparison
        XCTAssertEqual(comparison?.month, day(9, 1))
        XCTAssertEqual(comparison?.rate ?? 0, 2.0 / 3.0, accuracy: 0.001)
    }

    func testNoComparisonForASmallGapOrAShortLastMonth() {
        let both = totals(from: day(9, 1), through: day(9, 30)).merging(totals(from: day(10, 1), through: day(10, 31))) { $1 }
        XCTAssertNil(recap(both, today: day(11, 1)).comparison, "100 % both months")

        let late = nutrients.map {
            HistoryNutrient(id: $0.id, goalType: $0.goalType, target: $0.target, upperBound: nil,
                            createdAt: day(9, 26), isRemoved: false)
        }
        let short = totals(from: day(9, 26), through: day(9, 30), overrides: [day(9, 27): [omega: 0]])
            .merging(october) { $1 }
        XCTAssertNil(recap(short, today: day(11, 1), nutrients: late).comparison, "September had only 5 counted days")
    }

    // MARK: - Weekly nutrients

    func testWeeklyNutrientsCountWholeWeeksInsideTheMonth() {
        let zinc = UUID()
        var zincNutrient = HistoryNutrient(id: zinc, goalType: .minimum, target: 10, upperBound: nil,
                                           createdAt: day(8, 1), isRemoved: false)
        zincNutrient.schedule = NutrientSchedule().setting(.weekly(times: 2), from: day(8, 1), calendar: calendar)
        var all = october
        // Zinc twice in the weeks of 5, 12 and 19 October, once in the week of 26 October (which ends 1 November).
        for date in [6, 8, 13, 15, 20, 22, 27] { all[day(10, date), default: [:]][zinc] = 10 }
        let recap = recap(all, today: day(11, 2), nutrients: nutrients + [zincNutrient])
        let weekly = recap.weekly.first { $0.id == zinc }
        XCTAssertEqual(weekly?.weeks, 3, "5, 12 and 19 October; 26 October runs into November")
        XCTAssertEqual(weekly?.weeksMet, 3)
        XCTAssertFalse(recap.nutrients.contains { $0.id == zinc }, "judged by the week, not day by day")
    }

    // MARK: - Months

    func testMonthsAndRelease() {
        XCTAssertEqual(MonthlyRecap.monthStart(containing: day(10, 31, hour: 23), calendar: calendar), day(10, 1))
        XCTAssertEqual(MonthlyRecap.days(ofMonthStarting: day(2, 1), calendar: calendar).count, 28)
        XCTAssertEqual(MonthlyRecap.releaseDate(ofMonthStarting: day(10, 1), calendar: calendar), day(11, 1, hour: 18))
        XCTAssertEqual(MonthlyRecap.latestMonth(at: day(11, 1, hour: 9), calendar: calendar), day(10, 1))
        XCTAssertEqual(MonthlyRecap.latestMonth(at: day(10, 31, hour: 23), calendar: calendar), day(9, 1))
    }

    func testMissesOnSaturdaysAndSundaysReadAsWeekends() {
        var weekends = october
        for weekend in [3, 4, 10, 11, 17, 18, 24, 25, 31] { weekends[day(10, weekend)]?[omega] = 0 }
        let text = MonthlyRecapText(recap(weekends, today: day(11, 1)), calendar: calendar)
        XCTAssertTrue(text.summary.contains("Omega-3 slipped on weekends."), text.summary)
        XCTAssertEqual(text.cards.first { $0.kind == .slipped }?.detail, "Missed on weekends")
    }

    func testHistoryNamesTheRecapOutLast() {
        // On 28 October the week of 19 October (out on the 25th) is newer than September (out on 1 October).
        XCTAssertEqual(RecapSchedule.latestTab(week: day(10, 19), month: day(9, 1), year: nil, calendar: calendar), .week)
        // October comes out on Sunday 1 November, at 18:00 like the week ending that day: the month wins.
        XCTAssertEqual(RecapSchedule.latestTab(week: day(10, 19), month: day(10, 1), year: nil, calendar: calendar), .month)
        XCTAssertEqual(RecapSchedule.latestTab(week: day(10, 26), month: day(10, 1), year: nil, calendar: calendar), .month)
        XCTAssertEqual(RecapSchedule.latestTab(week: day(11, 2), month: day(10, 1), year: nil, calendar: calendar), .week)
        XCTAssertEqual(RecapSchedule.latestTab(week: nil, month: day(10, 1), year: nil, calendar: calendar), .month)
        XCTAssertEqual(RecapSchedule.latestTab(week: nil, month: nil, year: nil, calendar: calendar), .week)
    }

    // MARK: - Notification

    func testTheMonthsNotification() {
        // Set up mid-month: no numbers yet.
        let soFar = RecapSchedule.plan(month: recap(october, today: day(10, 15)), now: day(10, 15, hour: 9),
                                       calendar: calendar)
        XCTAssertEqual(soFar?.fireDate, day(11, 1, hour: 18))
        XCTAssertEqual(soFar?.identifier, "monthly-recap-202610")
        XCTAssertEqual(soFar?.title, "Your October in nutrx")
        XCTAssertEqual(soFar?.body, "See what you hit in October and what slipped.")
        XCTAssertEqual(soFar?.tab, .month)
        // On the 1st, the whole month's numbers.
        XCTAssertEqual(RecapSchedule.plan(month: recap(october, today: day(11, 1)), now: day(11, 1, hour: 9),
                                          calendar: calendar)?.body,
                       "You met 95% of your goals in October. Vitamin D was your steadiest.")
        XCTAssertNil(RecapSchedule.plan(month: recap(october, today: day(11, 1)), now: day(11, 1, hour: 19),
                                        calendar: calendar), "gone out")
        XCTAssertNil(RecapSchedule.plan(month: recap([:], today: day(10, 15)), now: day(10, 15, hour: 9),
                                        calendar: calendar), "nothing logged")

        XCTAssertEqual(RecapSchedule.upcomingMonth(at: day(10, 15), calendar: calendar), day(10, 1))
        XCTAssertEqual(RecapSchedule.upcomingMonth(at: day(11, 1, hour: 9), calendar: calendar), day(10, 1))
        XCTAssertEqual(RecapSchedule.upcomingMonth(at: day(11, 1, hour: 19), calendar: calendar), day(11, 1))
    }

    func testOneRecapANightTheLongest() {
        func plan(_ tab: RecapTab, _ date: Date) -> RecapSchedule.Plan {
            RecapSchedule.Plan(identifier: tab.rawValue, fireDate: date, body: "", tab: tab)
        }
        // Sunday 1 November: October and the week ending that day both at 18:00.
        let sunday = day(11, 1, hour: 18)
        XCTAssertEqual(RecapSchedule.oneANight([plan(.week, sunday), plan(.month, sunday)], calendar: calendar)
                           .map(\.tab), [.month])
        // 1 January: the year over December.
        let newYear = day(1, 1, year: 2027, hour: 18)
        XCTAssertEqual(RecapSchedule.oneANight([plan(.month, newYear), plan(.year, newYear), plan(.week, day(1, 3, year: 2027, hour: 18))],
                                               calendar: calendar).map(\.tab), [.year, .week])
        // Different nights: both, soonest first.
        XCTAssertEqual(RecapSchedule.oneANight([plan(.month, sunday), plan(.week, day(10, 25, hour: 18))], calendar: calendar)
                           .map(\.tab), [.week, .month])
    }

    func testTodaysMonthCardShowsOnTheFirstAndSecond() {
        // October's card: 1 and 2 November, all day (the month is over at midnight; 18:00 is the notification's).
        XCTAssertEqual(RecapSchedule.todayCardMonth(at: day(11, 1, hour: 8), isPro: true, dismissedMonth: nil,
                                                    calendar: calendar), day(10, 1))
        XCTAssertEqual(RecapSchedule.todayCardMonth(at: day(11, 2, hour: 23), isPro: true, dismissedMonth: nil,
                                                    calendar: calendar), day(10, 1))
        XCTAssertNil(RecapSchedule.todayCardMonth(at: day(11, 3), isPro: true, dismissedMonth: nil, calendar: calendar))
        XCTAssertNil(RecapSchedule.todayCardMonth(at: day(10, 31, hour: 23), isPro: true, dismissedMonth: nil,
                                                  calendar: calendar))
        XCTAssertNil(RecapSchedule.todayCardMonth(at: day(11, 1, hour: 8), isPro: false, dismissedMonth: nil,
                                                  calendar: calendar), "Pro only")
        XCTAssertNil(RecapSchedule.todayCardMonth(at: day(11, 1, hour: 8), isPro: true, dismissedMonth: day(10, 1),
                                                  calendar: calendar), "hidden with ✕ for October")
        XCTAssertEqual(RecapSchedule.todayCardMonth(at: day(11, 1, hour: 8), isPro: true, dismissedMonth: day(9, 1),
                                                    calendar: calendar), day(10, 1), "September's ✕ doesn't hide it")
        XCTAssertEqual(RecapSchedule.todayCardMonth(at: day(11, 15), isPro: true, dismissedMonth: nil,
                                                    ignoresWindow: true, calendar: calendar), day(10, 1), "Debug flag")
    }

    func testPicksNeedAWeekOfCountedDays() {
        let zinc = UUID()
        let late = HistoryNutrient(id: zinc, goalType: .minimum, target: 10, upperBound: nil, createdAt: day(10, 29),
                                   isRemoved: false)
        var all = october
        for date in 29...31 { all[day(10, date), default: [:]][zinc] = 10 }
        let recap = recap(all, today: day(11, 1), nutrients: nutrients + [late])
        XCTAssertEqual(recap.steadiest?.name, "Vitamin D", "Zinc's 3 of 3 days don't outrank 31 of 31")
        XCTAssertTrue(recap.nutrients.contains { $0.id == zinc }, "still counted in the totals")
    }

    // MARK: - Words

    private var octoberText: MonthlyRecapText {
        var september: [Date: [UUID: Double]] = [:]
        for date in 1...30 { september[day(9, date)] = [vitaminD: 4000, omega: 0, caffeine: 200] }
        let log = HistoryLog(nutrients: nutrients, totals: september.merging(october) { $1 }, today: day(11, 1),
                             calendar: calendar)
        return MonthlyRecapText(MonthlyRecap.build(log: log, names: names, month: day(10, 1), streaksEnabled: true),
                                calendar: calendar)
    }

    func testTheMonthsWords() {
        let text = octoberText
        XCTAssertEqual(text.range, "October 2026")
        XCTAssertEqual(text.headline, "88 of 93 goals met")
        XCTAssertEqual(text.percent, 95)
        XCTAssertEqual(text.ringValue, "26/31")
        XCTAssertEqual(text.summary, "In October you met 95% of your goals, with 26 full days. "
            + "Vitamin D was your steadiest, 31 of 31 days. Omega-3 slipped on Sundays. "
            + "Caffeine went over your limit on 1 day. Your best run was 6 days in a row. Up from 67% in September.")
        XCTAssertEqual(text.cacheKey, "month-2026-10")
        XCTAssertEqual(text.notificationTitle, "Your October in nutrx")
        XCTAssertEqual(text.notificationBody, "You met 95% of your goals in October. Vitamin D was your steadiest.")
        XCTAssertEqual(text.cards.map(\.label), ["Steadiest", "Slipped", "Day you tend to miss", "Best run", "Goals met"])
        XCTAssertEqual(text.cards.last?.detail, "Up from 67% in September")
        XCTAssertTrue(RecapPhrasing.isAcceptable(text.summary, for: text), "the template passes its own check")
    }

    func testTheMonthSoFarSaysSo() {
        let text = MonthlyRecapText(recap(october, today: day(10, 15)), calendar: calendar)
        XCTAssertEqual(text.range, "October so far")
        XCTAssertTrue(text.summary.hasPrefix("So far in October you've met"), text.summary)
        XCTAssertTrue(text.summary.contains("Vitamin D is your steadiest"), text.summary)
        XCTAssertTrue(text.summary.contains("Omega-3 has slipped on Sundays."), text.summary)
        XCTAssertTrue(text.summary.contains("Caffeine has gone over your limit on 1 day."), text.summary)
        XCTAssertTrue(text.summary.contains("Your best run is "), text.summary)
        XCTAssertEqual(MonthlyRecapText.firstTitle(nextMonthStart: day(11, 1), calendar: calendar),
                       "Your first monthly recap arrives on 1 November")
        XCTAssertEqual(MonthlyRecapText.firstBody(daysLogged: 3),
                       "You've logged 3 days so far. The recap on the 1st will cover the whole month.")
    }

    // MARK: - Rewording

    func testGroupedNumbersReadAsOne() {
        XCTAssertEqual(RecapPhrasing.numbers(in: "You met 3,960 of 5,400 goals, 73 %."), [3960, 5400, 73])
        XCTAssertEqual(RecapPhrasing.numbers(in: "18 full days, 2 of 3"), [18, 2, 3])
    }

    func testAdviceAboutTheNextMonthIsRejected() {
        let text = octoberText
        XCTAssertFalse(RecapPhrasing.isAcceptable("Vitamin D held all 31 days. Next month, keep Omega-3 going.", for: text))
        XCTAssertTrue(RecapPhrasing.isAcceptable("Vitamin D held all 31 days, and you met 95% of your goals.", for: text))
    }

    func testTheCacheKeepsEachKindApart() {
        var cache: [String: Any] = [:]
        for week in 0..<14 { cache[String(1_790_000_000 + week * 604_800)] = ["t", "s"] }  // before #136: no kind
        for month in 1...12 { cache["month-2025-\(String(format: "%02d", month))"] = ["t", "s"] }
        cache["month-2026-01"] = ["t", "s"]
        for year in 2022...2026 { cache["year-\(year)"] = ["t", "s"] }
        let pruned = RecapPhrasing.pruned(cache)
        XCTAssertEqual(pruned.keys.filter { !$0.contains("-") }.count, 12, "weeks aren't pushed out by months")
        XCTAssertEqual(pruned.keys.filter { $0.hasPrefix("month-") }.count, 12)
        XCTAssertNil(pruned["month-2025-01"], "the oldest month goes")
        XCTAssertEqual(Set(pruned.keys.filter { $0.hasPrefix("year-") }), ["year-2024", "year-2025", "year-2026"])
    }

    /// The weekly recap reads through the same tally: its facts are unchanged by the refactor (the weekly tests too).
    func testTheWeekAndTheMonthAgree() {
        let log = HistoryLog(nutrients: nutrients, totals: october, today: day(11, 1), calendar: calendar)
        let week = WeeklyRecap.build(log: log, names: names, week: day(10, 5), streaksEnabled: true)
        XCTAssertEqual(week.goalsCounted, 21)
        XCTAssertEqual(week.goalsMet, 19, "Caffeine over on the 6th, Omega-3 missed on Sunday the 11th")
        XCTAssertEqual(week.fullDays, 5)
    }
}
