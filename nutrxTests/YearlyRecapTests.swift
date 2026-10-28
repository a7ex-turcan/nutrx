import XCTest
@testable import nutrx

/// The yearly recap's facts and words (#136, docs/pro/RECAPS.md §3, §4), over 2026 (Thursday 1 January – Thursday
/// 31 December).
final class YearlyRecapTests: XCTestCase {
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

    private func nutrients(createdAt: Date? = nil) -> [HistoryNutrient] {
        let created = createdAt ?? day(6, 1, year: 2025)
        return [
            HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil, createdAt: created, isRemoved: false),
            HistoryNutrient(id: omega, goalType: .minimum, target: 1000, upperBound: nil, createdAt: created, isRemoved: false),
            HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil, createdAt: created, isRemoved: false),
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

    /// 2026: Omega-3 missed every day in March and on the 1st of every other month but May, nothing logged in
    /// August, everything else met. May (100%) stands out from the 99% months.
    private var year2026: [Date: [UUID: Double]] {
        var overrides: [Date: [UUID: Double]] = [:]
        for month in [1, 2, 4, 6, 7, 9, 10, 11, 12] { overrides[day(month, 1)] = [omega: 0] }
        for march in 1...31 { overrides[day(3, march)] = [omega: 0] }
        var totals = totals(from: day(1, 1), through: day(12, 31), overrides: overrides)
        for august in 1...31 { totals[day(8, august)] = nil }
        return totals
    }

    private func recap(_ totals: [Date: [UUID: Double]], today: Date, streaks: Bool = true,
                       nutrients: [HistoryNutrient]? = nil) -> YearlyRecap {
        let log = HistoryLog(nutrients: nutrients ?? self.nutrients(), totals: totals, today: today, calendar: calendar)
        return YearlyRecap.build(log: log, names: names, year: day(6, 15), streaksEnabled: streaks)
    }

    // MARK: - Facts

    func testAWholeYearAddsUpItsMonths() {
        let log = HistoryLog(nutrients: nutrients(), totals: year2026, today: day(1, 2, year: 2027), calendar: calendar)
        let recap = YearlyRecap.build(log: log, names: names, year: day(6, 15), streaksEnabled: true)
        XCTAssertTrue(recap.isYearOver)
        XCTAssertEqual(recap.yearStart, day(1, 1))
        XCTAssertEqual(recap.months.count, 12)
        XCTAssertEqual(recap.daysElapsed, 365)
        XCTAssertEqual(recap.daysLogged, 365 - 31)
        // The year is its months: each bar is that month's recap.
        var goalsMet = 0, goalsCounted = 0, fullDays = 0
        for month in recap.months {
            let monthly = MonthlyRecap.build(log: log, names: names, month: month.monthStart, streaksEnabled: true)
            XCTAssertEqual(month.goalsMet, monthly.goalsMet)
            XCTAssertEqual(month.goalsCounted, monthly.goalsCounted)
            goalsMet += monthly.goalsMet
            goalsCounted += monthly.goalsCounted
            fullDays += monthly.fullDays
        }
        XCTAssertEqual(recap.goalsMet, goalsMet)
        XCTAssertEqual(recap.goalsCounted, goalsCounted)
        XCTAssertEqual(recap.fullDays, fullDays)
        XCTAssertEqual(recap.fullDays, 365 - 31 - 31 - 9, "March missed Omega-3, August nothing logged, nine 1sts")
        XCTAssertEqual(recap.goalsCounted, 365 * 3)
        XCTAssertEqual(recap.goalsMet, 365 * 3 - 31 - 31 * 3 - 9)
        XCTAssertEqual(recap.steadiest?.name, "Vitamin D")
        XCTAssertEqual(recap.steadiest?.daysMet, 334)
    }

    func testTheYearSoFarCountsOnlyFinishedDays() {
        let recap = recap(year2026, today: day(10, 15))
        XCTAssertFalse(recap.isYearOver)
        XCTAssertEqual(recap.lastDay, day(10, 14))
        XCTAssertEqual(recap.daysElapsed, 287)
        XCTAssertEqual(recap.months[9].daysElapsed, 14)
        XCTAssertNil(recap.months[10].rate, "November hasn't started")
    }

    func testBestMonthNeedsTenCountedDaysAndTwoMonths() {
        let recap = recap(year2026, today: day(1, 2, year: 2027))
        XCTAssertEqual(recap.bestMonth?.monthStart, day(5, 1))
        XCTAssertEqual(recap.months[7].rate, 0, "August met nothing")

        // Two months both at 100%: neither stands out.
        let even = self.recap(totals(from: day(1, 1), through: day(2, 28)), today: day(3, 1),
                              nutrients: nutrients(createdAt: day(1, 1)))
        XCTAssertNil(even.bestMonth)

        // Only January counted: no "best month" of one.
        let january = self.recap(totals(from: day(1, 1), through: day(1, 31)), today: day(2, 1),
                            nutrients: nutrients(createdAt: day(1, 1)))
        XCTAssertNil(january.bestMonth)

        // A better month with only 9 counted days doesn't count.
        let late = nutrients(createdAt: day(1, 1))
        var data = totals(from: day(1, 1), through: day(2, 9), overrides: [day(1, 5): [omega: 0]])
        data.merge(totals(from: day(2, 1), through: day(2, 9))) { $1 }
        let short = self.recap(data, today: day(2, 10), nutrients: late)
        XCTAssertNil(short.bestMonth, "February has 9 counted days")
    }

    func testMostLoggedMonth() {
        let recap = recap(year2026, today: day(1, 2, year: 2027))
        XCTAssertEqual(recap.mostLogged?.monthStart, day(1, 1), "31 of 31, the earliest such month")
        XCTAssertEqual(recap.mostLogged?.daysLogged, 31)
        XCTAssertEqual(recap.mostLogged?.daysElapsed, 31)
    }

    func testTheLongestStreakRunsAcrossMonthsButNotIntoTheYearBefore() {
        // Full days from 20 December 2025 to 10 February 2026; a miss on 11 February.
        let data = totals(from: day(12, 20, year: 2025), through: day(2, 11),
                          overrides: [day(2, 11): [vitaminD: 0]])
        let recap = recap(data, today: day(3, 1))
        XCTAssertEqual(recap.longestStreak, 41, "1 January to 10 February; December doesn't count")
        XCTAssertNil(self.recap(data, today: day(3, 1), streaks: false).longestStreak)
    }

    func testTheSteadiestNeedsThirtyCountedDays() {
        let zinc = UUID()
        var all = nutrients(createdAt: day(1, 1))
        all.append(HistoryNutrient(id: zinc, goalType: .minimum, target: 10, upperBound: nil, createdAt: day(12, 10),
                                   isRemoved: false))
        var data = totals(from: day(1, 1), through: day(12, 31), overrides: [day(3, 3): [vitaminD: 0, omega: 0]])
        for date in data.keys where date >= day(12, 10) { data[date]?[zinc] = 10 }
        let log = HistoryLog(nutrients: all, totals: data, today: day(1, 2, year: 2027), calendar: calendar)
        let recap = YearlyRecap.build(log: log, names: names.merging([zinc: "Zinc"]) { $1 }, year: day(1, 1),
                                      streaksEnabled: true)
        XCTAssertEqual(recap.steadiest?.name, "Caffeine", "Zinc's 22 of 22 days are too few")
    }

    func testAFirstYear() {
        let recap = recap(totals(from: day(4, 10), through: day(12, 31)), today: day(1, 2, year: 2027),
                          nutrients: nutrients(createdAt: day(4, 10)))
        XCTAssertEqual(recap.firstMonth, day(4, 1))
        XCTAssertTrue(recap.started.isEmpty)
        let text = YearlyRecapText(recap, calendar: calendar)
        XCTAssertTrue(text.summary.hasSuffix("You started tracking in April."), text.summary)
        XCTAssertEqual(text.cards.last?.label, "Since you started")
        XCTAssertEqual(text.cards.last?.value, "April")
    }

    func testNutrientsStartedThisYear() {
        let magnesium = UUID()
        var all = nutrients()
        all.append(HistoryNutrient(id: magnesium, goalType: .minimum, target: 200, upperBound: nil,
                                   createdAt: day(4, 12), isRemoved: false))
        let removed = UUID()
        all.append(HistoryNutrient(id: removed, goalType: .minimum, target: 1, upperBound: nil,
                                   createdAt: day(5, 2), isRemoved: true))
        let log = HistoryLog(nutrients: all, totals: year2026, today: day(1, 2, year: 2027), calendar: calendar)
        let recap = YearlyRecap.build(log: log, names: names.merging([magnesium: "Magnesium", removed: "Gone"]) { $1 },
                                      year: day(1, 1), streaksEnabled: true)
        XCTAssertNil(recap.firstMonth)
        XCTAssertEqual(recap.started.map(\.name), ["Magnesium"], "not the removed one")
        let text = YearlyRecapText(recap, calendar: calendar)
        XCTAssertTrue(text.summary.hasSuffix("You started tracking Magnesium in April."), text.summary)
        XCTAssertEqual(text.cards.last?.label, "New this year")
        XCTAssertEqual(text.cards.last?.detail, "Since April")
        XCTAssertEqual(text.cards.last?.nutrientID, magnesium)
    }

    // MARK: - Years

    func testYearsAndRelease() {
        XCTAssertEqual(YearlyRecap.yearStart(containing: day(12, 31, hour: 23), calendar: calendar), day(1, 1))
        XCTAssertEqual(YearlyRecap.days(ofYearStarting: day(1, 1), calendar: calendar).count, 365)
        XCTAssertEqual(YearlyRecap.days(ofYearStarting: day(1, 1, year: 2028), calendar: calendar).count, 366)
        XCTAssertEqual(YearlyRecap.releaseDate(ofYearStarting: day(1, 1), calendar: calendar),
                       day(1, 1, year: 2027, hour: 18))
        XCTAssertEqual(YearlyRecap.latestYear(at: day(1, 1, year: 2027, hour: 9), calendar: calendar), day(1, 1))
        XCTAssertEqual(YearlyRecap.latestYear(at: day(12, 31, hour: 23), calendar: calendar), day(1, 1, year: 2025))
    }

    func testTodaysYearCardShowsOnTheFirstWeekOfJanuary() {
        func card(_ now: Date, isPro: Bool = true, dismissed: Date? = nil, debug: Bool = false) -> Date? {
            RecapSchedule.todayCardYear(at: now, isPro: isPro, dismissedYear: dismissed, ignoresWindow: debug,
                                        calendar: calendar)
        }
        XCTAssertEqual(card(day(1, 1, year: 2027, hour: 8)), day(1, 1))
        XCTAssertEqual(card(day(1, 7, year: 2027, hour: 23)), day(1, 1))
        XCTAssertNil(card(day(1, 8, year: 2027)))
        XCTAssertNil(card(day(12, 31, hour: 23)))
        XCTAssertNil(card(day(1, 1, year: 2027, hour: 8), isPro: false), "Pro only")
        XCTAssertNil(card(day(1, 1, year: 2027, hour: 8), dismissed: day(1, 1)), "hidden with ✕ for 2026")
        XCTAssertEqual(card(day(6, 1, year: 2027), debug: true), day(1, 1), "Debug flag")
    }

    func testHistoryNamesTheYearInItsFirstWeek() {
        // 1 January 2027 is a Friday: 2026 and December both come out at 18:00, and the year wins.
        XCTAssertEqual(RecapSchedule.latestTab(week: day(12, 21), month: day(12, 1), year: day(1, 1), calendar: calendar),
                       .year)
        // Until Sunday 10 January's week.
        XCTAssertEqual(RecapSchedule.latestTab(week: day(1, 4, year: 2027), month: day(12, 1), year: day(1, 1),
                                               calendar: calendar), .week)
        // In the rest of the year last year is old news.
        XCTAssertEqual(RecapSchedule.latestTab(week: day(10, 19), month: day(10, 1), year: day(1, 1, year: 2025),
                                               calendar: calendar), .month)
    }

    func testTheYearsNotification() {
        let soFar = RecapSchedule.plan(year: recap(year2026, today: day(12, 15)), now: day(12, 15, hour: 9),
                                       calendar: calendar)
        XCTAssertEqual(soFar?.fireDate, day(1, 1, year: 2027, hour: 18))
        XCTAssertEqual(soFar?.identifier, "yearly-recap-2026")
        XCTAssertEqual(soFar?.title, "Your 2026 in nutrx")
        XCTAssertEqual(soFar?.body, "See what you hit in 2026 and what slipped.")
        XCTAssertEqual(soFar?.tab, .year)
        XCTAssertEqual(RecapSchedule.plan(year: recap(year2026, today: day(1, 1, year: 2027)),
                                          now: day(1, 1, year: 2027, hour: 9), calendar: calendar)?.body,
                       "You met 88% of your goals in 2026. Vitamin D was your steadiest.")

        // Only read in December and on 1 January until it goes: two slots otherwise, three then.
        XCTAssertTrue(RecapSchedule.yearIsDue(at: day(12, 5), calendar: calendar))
        XCTAssertTrue(RecapSchedule.yearIsDue(at: day(1, 1, year: 2027, hour: 9), calendar: calendar))
        XCTAssertFalse(RecapSchedule.yearIsDue(at: day(1, 1, year: 2027, hour: 19), calendar: calendar))
        XCTAssertFalse(RecapSchedule.yearIsDue(at: day(6, 1), calendar: calendar))
        XCTAssertEqual(RecapSchedule.slots(at: day(12, 5), calendar: calendar), 3)
        XCTAssertEqual(RecapSchedule.slots(at: day(6, 1), calendar: calendar), 2)
        XCTAssertEqual(RecapSchedule.upcomingYear(at: day(1, 1, year: 2027, hour: 9), calendar: calendar), day(1, 1))
        XCTAssertEqual(RecapSchedule.upcomingYear(at: day(1, 1, year: 2027, hour: 19), calendar: calendar),
                       day(1, 1, year: 2027))
    }

    // MARK: - Words

    func testTheYearsWords() {
        let text = YearlyRecapText(recap(year2026, today: day(1, 2, year: 2027)), calendar: calendar)
        XCTAssertEqual(text.range, "2026")
        XCTAssertEqual(text.headline, "962 of 1,095 goals met")
        XCTAssertEqual(text.percent, 88)
        XCTAssertEqual(text.summary, "In 2026 you logged on 334 days and met 88% of your goals. "
            + "Your best month was May, at 100%. Vitamin D was your steadiest, 334 of 365 days. "
            + "Your longest run was 60 days in a row.")
        // 2 April to 31 May.
        XCTAssertEqual(text.cacheKey, "year-2026")
        XCTAssertEqual(text.cards.map(\.label), ["Best month", "Steadiest", "Longest run", "Days logged"])
        XCTAssertEqual(text.cards.last?.detail, "Most in January, 31\u{00A0}of\u{00A0}31")
        XCTAssertEqual(text.todayLine, "**962**\u{00A0}of\u{00A0}1,095\u{00A0}goals · Vitamin\u{00A0}D\u{00A0}steadiest")
        XCTAssertEqual(text.historyLine, "Latest: 2026 · 962\u{00A0}of\u{00A0}1,095\u{00A0}goals")
        XCTAssertTrue(RecapPhrasing.isAcceptable(text.summary, for: text), "the template passes its own check")
        XCTAssertTrue(RecapPhrasing.isAcceptable("You met 962 of 1,095 goals in 2026, and Vitamin D was your steadiest.",
                                                 for: text), "a grouped number reads as one")
        XCTAssertFalse(RecapPhrasing.isAcceptable("Vitamin D was your steadiest. Aim higher next year.", for: text))
    }

    func testTheYearSoFarSaysSo() {
        let text = YearlyRecapText(recap(year2026, today: day(10, 15)), calendar: calendar)
        XCTAssertEqual(text.range, "2026 so far")
        XCTAssertTrue(text.summary.hasPrefix("So far in 2026 you've logged on"), text.summary)
        XCTAssertTrue(text.summary.contains("Your best month is May"), text.summary)
        XCTAssertTrue(text.summary.contains("Vitamin D is your steadiest"), text.summary)
        XCTAssertTrue(text.summary.contains("Your longest run is "), text.summary)
        XCTAssertEqual(YearlyRecapText.firstTitle(calendar: calendar), "Your first yearly recap arrives on 1 January")
    }

    func testTheBarsReadEachMonth() {
        let text = YearlyRecapText(recap(year2026, today: day(1, 2, year: 2027)), calendar: calendar)
        XCTAssertTrue(text.barsAccessibilityValue.hasPrefix("January 99%, February 99%, March 67%"),
                      text.barsAccessibilityValue)
        XCTAssertTrue(text.barsAccessibilityValue.contains("May 100%, best, June 99%"), text.barsAccessibilityValue)
        XCTAssertTrue(text.barsAccessibilityValue.contains("August 0%"), text.barsAccessibilityValue)
        let soFar = YearlyRecapText(recap(year2026, today: day(10, 15)), calendar: calendar)
        XCTAssertTrue(soFar.barsAccessibilityValue.hasSuffix("October 98%"), "November hasn't begun")
        XCTAssertEqual(text.barLetter(text.recap.months[4]), "M")
    }

    // MARK: - Speed

    /// docs/pro/RECAPS.md §7: a year of eight logs a day (eight nutrients). No hard limit: a loaded simulator would
    /// make one flaky; `measure` reports the time.
    func testBuildingAFullYearOfEightNutrients() {
        let ids = (0..<8).map { _ in UUID() }
        let all = ids.map {
            HistoryNutrient(id: $0, goalType: .minimum, target: 100, upperBound: nil, createdAt: day(1, 1), isRemoved: false)
        }
        var data: [Date: [UUID: Double]] = [:]
        for offset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: offset, to: day(1, 1))!
            data[date] = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0 == offset % 8 ? 50 : 100) })
        }
        let names = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, "Nutrient \($0)") })
        let log = HistoryLog(nutrients: all, totals: data, today: day(1, 2, year: 2027), calendar: calendar)
        var recap: YearlyRecap?
        measure {
            recap = YearlyRecap.build(log: log, names: names, year: day(1, 1), streaksEnabled: true)
        }
        XCTAssertEqual(recap?.goalsCounted, 365 * 8)
        XCTAssertEqual(recap?.goalsMet, 365 * 7)
    }
}
