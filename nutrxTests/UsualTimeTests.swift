import XCTest
@testable import nutrx

/// The usual time a reminder learns (#137, docs/pro/REMINDERS.md §2), with today Wednesday 28 October 2026.
final class UsualTimeTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private var today: Date { day(28) }

    private func day(_ day: Int, month: Int = 10, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func samples(_ times: [(day: Int, minutes: Int)]) -> [UsualTime.Sample] {
        times.map { UsualTime.Sample(day: day($0.day), minutes: $0.minutes) }
    }

    func testItNeedsSevenDays() {
        let six = samples((20...25).map { ($0, 8 * 60) })
        XCTAssertEqual(UsualTime.result(six, calendar: calendar), .learning(samples: 6))
        let seven = samples((20...26).map { ($0, 8 * 60) })
        XCTAssertEqual(UsualTime.result(seven, calendar: calendar), .learned(weekdays: 480, weekends: 480))
    }

    func testTheTimeByWhichItWasLoggedOnThreeDaysInFour() {
        // Seven days: the sixth earliest (nearest rank of 75 %) is 8:25.
        XCTAssertEqual(UsualTime.percentile([480, 485, 490, 495, 500, 505, 512]), 505)
        // Rounded up to the next 5 minutes: 8:27 → 8:30.
        XCTAssertEqual(UsualTime.percentile([480, 485, 490, 495, 500, 507, 512]), 510)
        XCTAssertEqual(UsualTime.percentile([600, 420, 450, 430, 440, 445, 460, 470]), 460, "unsorted input")
    }

    func testOnlyEachDaysFirstLogInTheLastFourWeeks() {
        let logs = [
            day(27, hour: 8, minute: 10), day(27, hour: 7, minute: 50), day(27, hour: 21),  // first: 7:50
            day(28, hour: 6),                                                              // today: never
            day(30, month: 9, hour: 9),                                                    // 28 days back: in
            day(29, month: 9, hour: 9),                                                    // 29 days back: out
        ]
        let samples = UsualTime.samples(logs: logs, today: today.addingTimeInterval(9 * 3600), isDue: { _ in true },
                                        calendar: calendar)
        XCTAssertEqual(samples, [UsualTime.Sample(day: day(30, month: 9), minutes: 540),
                                 UsualTime.Sample(day: day(27), minutes: 470)])
    }

    func testOnlyDaysItWasDue() {
        let logs = (19...27).map { day($0, hour: 8) }
        // Due only on weekdays: the 24th and 25th (a weekend) give no sample.
        let samples = UsualTime.samples(logs: logs, today: today, isDue: { !self.calendar.isDateInWeekend($0) },
                                        calendar: calendar)
        XCTAssertEqual(samples.map { self.calendar.component(.day, from: $0.day) }, [19, 20, 21, 22, 23, 26, 27])
    }

    func testWeekdaysAndWeekendsGetTheirOwnTimesAnHourApart() {
        // Weekdays at 8:00, weekends at 10:30, four weeks of them.
        let days = (1...27).map { day($0) }
        let times = days.map { (calendar.component(.day, from: $0), calendar.isDateInWeekend($0) ? 630 : 480) }
        let result = UsualTime.result(samples(times), calendar: calendar)
        XCTAssertEqual(result, .learned(weekdays: 480, weekends: 630))
        XCTAssertEqual(result.minutes(on: day(24), calendar: calendar), 630, "Saturday")
        XCTAssertEqual(result.minutes(on: day(26), calendar: calendar), 480, "Monday")

        // Under an hour apart: one time for every day.
        let close = days.map { (calendar.component(.day, from: $0), calendar.isDateInWeekend($0) ? 520 : 480) }
        guard case let .learned(weekdays, weekends) = UsualTime.result(samples(close), calendar: calendar) else {
            return XCTFail("learned")
        }
        XCTAssertEqual(weekdays, weekends)

        // Three weekend days aren't enough for their own time.
        let fewWeekends = samples([(19, 480), (20, 480), (21, 480), (22, 480), (23, 480), (24, 630), (25, 630), (18, 630)])
        guard case let .learned(a, b) = UsualTime.result(fewWeekends, calendar: calendar) else { return XCTFail("learned") }
        XCTAssertEqual(a, b)
    }

    func testAHabitAroundMidnightKeepsTheSetTime() {
        XCTAssertEqual(UsualTime.result(samples((19...27).map { ($0, 23 * 60 + 40) }), calendar: calendar), .tooLate)
        XCTAssertEqual(UsualTime.result(samples((19...27).map { ($0, 23 * 60 + 30) }), calendar: calendar),
                       .learned(weekdays: 1410, weekends: 1410))
        XCTAssertNil(UsualTime.Result.tooLate.minutes(on: day(26), calendar: calendar))
    }

    func testAStacksDayIsWhenAllItsDueNutrientsWereLogged() {
        let vitaminD = samples([(20, 480), (21, 485), (22, 490)])
        let omega = samples([(20, 500), (22, 470)])
        let stack = UsualTime.stackSamples([
            (vitaminD, { _ in true }),
            // Omega-3 isn't due on the 21st, so Vitamin D alone decides that day.
            (omega, { self.calendar.component(.day, from: $0) != 21 }),
        ])
        XCTAssertEqual(stack, samples([(20, 500), (21, 485), (22, 490)]))
        // A day one due nutrient wasn't logged gives nothing.
        XCTAssertEqual(UsualTime.stackSamples([(vitaminD, { _ in true }), (omega, { _ in true })]).map(\.minutes),
                       [500, 490])
    }

    // MARK: - Planning

    func testWhichTimeIsPlanned() {
        let learned = UsualTime.Result.learned(weekdays: 510, weekends: 615)
        XCTAssertEqual(UsualTime.planned(start: 540, result: learned, isPro: true).weekends, 615)
        XCTAssertEqual(UsualTime.planned(start: 540, result: learned, isPro: nil).weekdays, 510,
                       "an entitlement not known yet keeps the learned time")
        XCTAssertEqual(UsualTime.planned(start: 540, result: learned, isPro: false).weekdays, 540, "without Pro")
        XCTAssertEqual(UsualTime.planned(start: 540, result: .learning(samples: 3), isPro: true).weekdays, 540)
        XCTAssertEqual(UsualTime.planned(start: 540, result: .tooLate, isPro: true).weekends, 540)
    }

    // MARK: - Words

    func testTheWords() {
        let en = Locale(identifier: "en_GB")
        // The time's own style is the locale's; the words around it are what's checked.
        let t830 = UsualTimeText.time(510, calendar: calendar, locale: en)
        let t1015 = UsualTimeText.time(615, calendar: calendar, locale: en)
        XCTAssertTrue(t830.contains("8:30") && t1015.contains("10:15"), t830)
        XCTAssertEqual(UsualTimeText.summary(.learned(weekdays: 510, weekends: 510), start: "09:00", isPro: true,
                                             calendar: calendar, locale: en), "Usually by \(t830)")
        XCTAssertEqual(UsualTimeText.summary(.learned(weekdays: 510, weekends: 615), start: "09:00", isPro: true,
                                             calendar: calendar, locale: en), "\(t830), weekends \(t1015)")
        XCTAssertEqual(UsualTimeText.summary(.learning(samples: 3), start: "09:00", isPro: true), "Learning (09:00)")
        XCTAssertEqual(UsualTimeText.summary(.learned(weekdays: 510, weekends: 510), start: "09:00", isPro: false),
                       "09:00", "without Pro the starting time fires")
        XCTAssertEqual(UsualTimeText.explanation(.learning(samples: 3), start: "09:00", isPro: true, name: "Vitamin D"),
                       "Learning your usual time: 3 of 7 days logged. Until then, nutrx reminds you at 09:00.")
        XCTAssertEqual(UsualTimeText.explanation(.learned(weekdays: 510, weekends: 510), start: "09:00", isPro: true,
                                                 name: "Vitamin D", calendar: calendar, locale: en),
                       "You usually log Vitamin D by \(t830). nutrx reminds you then, only if you haven't logged it.")
        XCTAssertTrue(UsualTimeText.explanation(.tooLate, start: "09:00", isPro: true, name: "Magnesium")
            .hasPrefix("You usually log Magnesium close to midnight"))
        XCTAssertTrue(UsualTimeText.explanation(.learning(samples: 3), start: "09:00", isPro: false, name: "Zinc")
            .hasPrefix("Reminders at your usual time are part of nutrx Pro."))
        XCTAssertEqual(UsualTimeText.startingTimeFooter(.learned(weekdays: 480, weekends: 480), name: "Zinc", setTimes: 1),
                       "Used instead if nutrx Pro ends.")
        XCTAssertEqual(UsualTimeText.startingTimeFooter(.learning(samples: 2), name: "Zinc", setTimes: 3),
                       "Used until nutrx has learned when you usually log Zinc. One reminder a day, for the first time "
                       + "you log it. Your 3 set times come back if you switch back.")
    }
}
