import XCTest
@testable import nutrx

/// Health trends over fixed four-week fixtures: what's found, when nothing is said, and the words.
final class HealthTrendsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private let today = Date(timeIntervalSince1970: 1_791_590_400)  // 10 October 2026, UTC midnight
    private let caffeineLimit = AnalyticsGoal(goalType: .maximum, target: 400, upperBound: nil)

    /// The 28 completed days before today, newest first.
    private var window: [Date] { (1...28).map { calendar.date(byAdding: .day, value: -$0, to: today)! } }

    private func state(_ days: [(Date, Double, HealthDay)], goal: AnalyticsGoal? = nil,
                       createdAt: Date? = nil, logged: Set<Date>? = nil) -> HealthTrends.State {
        HealthTrends.state(totals: Dictionary(uniqueKeysWithValues: days.map { ($0.0, $0.1) }),
                           loggedDays: logged ?? Set(days.map(\.0)),
                           health: Dictionary(uniqueKeysWithValues: days.map { ($0.0, $0.2) }),
                           goal: goal ?? caffeineLimit,
                           createdAt: createdAt ?? calendar.date(byAdding: .day, value: -60, to: today)!,
                           today: today, calendar: calendar)
    }

    private func text(_ goal: AnalyticsGoal? = nil) -> HealthText {
        HealthText(nutrientName: "Caffeine", unit: "mg", goal: goal ?? caffeineLimit, locale: calendar.locale!)
    }

    // MARK: - Findings

    func testShorterSleepAfterDaysOverTheLimitsThreshold() throws {
        // The design's card: 9 days over 300 mg with 6 h 35 of sleep, 19 days under with 7 h 15.
        let days = window.enumerated().map { index, day in
            index < 9 ? (day, 350.0, HealthDay(sleepMinutes: 395)) : (day, 200.0, HealthDay(sleepMinutes: 435))
        }
        guard case .findings(let findings) = state(days) else { return XCTFail("expected a finding") }
        let sleep = try XCTUnwrap(findings.first { $0.kind == .sleep })
        XCTAssertEqual(sleep.threshold, 300)
        XCTAssertEqual(sleep.difference, -40)
        let words = text()
        XCTAssertEqual(words.sentence(sleep), "On days Caffeine passes 300 mg, you seem to sleep about 40 minutes less on average.")
        XCTAssertEqual(words.labels(sleep).0, "Over 300 mg")
        XCTAssertEqual(words.labels(sleep).1, "Other days")
        XCTAssertEqual(words.value(sleep.first, of: sleep), "6 h 35")
        XCTAssertEqual(words.value(sleep.second, of: sleep), "7 h 15")
        XCTAssertEqual(words.basis(sleep), "Based on 9 days over 300 mg and 19 days under.")
    }

    func testMoreOnWorkoutDays() throws {
        // 12 workout days at 290 mg, 16 rest days at 210 mg.
        let days = window.enumerated().map { index, day in
            index < 12 ? (day, 290.0, HealthDay(workedOut: true)) : (day, 210.0, HealthDay(activeEnergy: 300))
        }
        guard case .findings(let findings) = state(days) else { return XCTFail("expected a finding") }
        let workouts = try XCTUnwrap(findings.first { $0.kind == .workouts })
        XCTAssertEqual(workouts.difference, 80)
        let words = text()
        XCTAssertEqual(words.sentence(workouts), "On days you work out, you log about 80 mg more Caffeine on average.")
        XCTAssertEqual(words.value(workouts.first, of: workouts), "290 mg")
        XCTAssertEqual(words.basis(workouts), "Based on 12 workout days and 16 rest days.")
    }

    func testActiveEnergyWhenThereAreNoWorkouts() throws {
        let days = window.enumerated().map { index, day in
            index % 2 == 0 ? (day, 300.0, HealthDay(activeEnergy: 700)) : (day, 150.0, HealthDay(activeEnergy: 250))
        }
        guard case .findings(let findings) = state(days) else { return XCTFail("expected a finding") }
        let energy = try XCTUnwrap(findings.first { $0.kind == .activeEnergy })
        XCTAssertEqual(energy.difference, 150)
        XCTAssertEqual(text().sentence(energy), "On your more active days, you log about 150 mg more Caffeine on average.")
        XCTAssertEqual(text().basis(energy), "Based on 14 days more active and 14 days less active.")
    }

    func testReachingAnAtLeastGoalUsesTheGoal() throws {
        let vitaminD = AnalyticsGoal(goalType: .minimum, target: 4000, upperBound: nil)
        let days = window.enumerated().map { index, day in
            index < 10 ? (day, 4000.0, HealthDay(sleepMinutes: 450)) : (day, 1000.0, HealthDay(sleepMinutes: 420))
        }
        guard case .findings(let findings) = state(days, goal: vitaminD) else { return XCTFail("expected a finding") }
        let sleep = try XCTUnwrap(findings.first)
        let words = HealthText(nutrientName: "Vitamin D", unit: "IU", goal: vitaminD, locale: calendar.locale!)
        XCTAssertEqual(words.sentence(sleep), "On days you reach your Vitamin D goal, you seem to sleep about 30 minutes more on average.")
        XCTAssertEqual(words.labels(sleep).0, "Goal met")
        XCTAssertEqual(words.basis(sleep), "Based on 10 days with the goal met and 18 days without.")
    }

    func testARangesGoalMetExcludesDaysAboveItsMaximum() throws {
        // Protein 120–160 g: days at 200 g are over the range, not "goal met", so they sit with the other days.
        let protein = AnalyticsGoal(goalType: .range, target: 120, upperBound: 160)
        let days = window.enumerated().map { index, day -> (Date, Double, HealthDay) in
            switch index {
            case 0..<8: return (day, 140, HealthDay(sleepMinutes: 460))
            case 8..<14: return (day, 200, HealthDay(sleepMinutes: 400))
            default: return (day, 80, HealthDay(sleepMinutes: 420))
            }
        }
        guard case .findings(let findings) = state(days, goal: protein) else { return XCTFail("expected a finding") }
        let sleep = try XCTUnwrap(findings.first { $0.kind == .sleep })
        XCTAssertEqual(sleep.first.days, 8, "only days within the range")
        XCTAssertEqual(sleep.second.days, 20)
    }

    func testTheFooterNamesTheDevice() {
        XCTAssertEqual(HealthText.footer(device: "iPad"), "Patterns in your own data, not causes. Worked out on this iPad.")
    }

    // MARK: - When nothing is said

    func testTooFewPairedDays() {
        let days = window.prefix(9).map { ($0, 200.0, HealthDay(sleepMinutes: 420)) }
        XCTAssertEqual(state(days), .notEnoughData(pairedDays: 9))
        XCTAssertEqual(HealthText.progress(pairedDays: 9), "9 of 14 days")
        XCTAssertEqual(HealthText.progress(pairedDays: 20), "14 of 14 days")
    }

    func testDaysWithoutALogDontPair() {
        // Health data every day, but nutrx used on only 10 of them: those days aren't 0 mg.
        let days = window.map { ($0, 0.0, HealthDay(sleepMinutes: 420)) }
        XCTAssertEqual(state(days, logged: Set(window.prefix(10))), .notEnoughData(pairedDays: 10))
    }

    func testDaysBeforeTheNutrientDontPair() {
        let days = window.map { ($0, 200.0, HealthDay(sleepMinutes: 420)) }
        let created = calendar.date(byAdding: .day, value: -12, to: today)!
        XCTAssertEqual(state(days, createdAt: created), .notEnoughData(pairedDays: 12))
    }

    func testNoHealthData() {
        let days = window.map { ($0, 200.0, HealthDay()) }
        XCTAssertEqual(state(days), .noHealthData)
    }

    func testSmallDifferencesArentPatterns() {
        // 10 minutes of sleep and 5% of intake: within what any week varies by.
        let days = window.enumerated().map { index, day in
            index < 14
                ? (day, 320.0, HealthDay(sleepMinutes: 420, workedOut: true))
                : (day, 305.0, HealthDay(sleepMinutes: 430))
        }
        XCTAssertEqual(state(days), .noPattern(checkedDays: 28))
        XCTAssertEqual(text().noPattern,
                       "No clear pattern yet. Your Caffeine looks about the same whatever your sleep and workouts.")
    }

    func testAGroupNeedsFourDays() {
        // Only 3 days over 300 mg: too few to compare, however different their sleep.
        let days = window.enumerated().map { index, day in
            index < 3 ? (day, 350.0, HealthDay(sleepMinutes: 300)) : (day, 200.0, HealthDay(sleepMinutes: 450))
        }
        XCTAssertEqual(state(days), .noPattern(checkedDays: 28))
    }

    // MARK: - Words

    func testNumbers() {
        XCTAssertEqual(HealthText.sleepText(395), "6 h 35")
        XCTAssertEqual(HealthText.sleepText(420), "7 h")
        XCTAssertEqual(HealthText.sleepText(425), "7 h 05")
        XCTAssertEqual(HealthText.sleepText(45), "45 min")
        XCTAssertEqual(HealthText.roundedMinutes(38), 40)
        XCTAssertEqual(HealthText.roundedMinutes(2), 5)
        XCTAssertEqual(text().amountText(2.5), "2.5 mg")
        XCTAssertEqual(text().amountText(1280), "1,280 mg")
    }

    func testNeverAdvises() {
        let days = window.enumerated().map { index, day in
            index < 9 ? (day, 350.0, HealthDay(sleepMinutes: 395, workedOut: true)) : (day, 200.0, HealthDay(sleepMinutes: 435))
        }
        guard case .findings(let findings) = state(days) else { return XCTFail("expected findings") }
        for finding in findings {
            let sentence = text().sentence(finding).lowercased()
            for word in ["should", "try", "recommend", "cause", "because", "reduce", "increase"] {
                XCTAssertFalse(sentence.contains(word), "\(word) in \(sentence)")
            }
        }
    }
}
