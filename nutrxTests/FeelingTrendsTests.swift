import XCTest
import SwiftData
@testable import nutrx

/// How you feel's patterns (nutrx Pro, #133, docs/pro/HOW-YOU-FEEL.md §3): the days a nutrient's goal was met against
/// the others, per question, over four weeks, and their words.
final class FeelingTrendsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 20))! }

    /// `daysAgo` before today, at the start of the day.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: today))!
    }

    private let atLeast400 = AnalyticsGoal(goalType: .minimum, target: 400, upperBound: nil)

    /// Magnesium met on the days in `met` (of the last 28), 0 on the rest; every day logged.
    private func totals(met: Set<Int>) -> [Date: Double] {
        Dictionary(uniqueKeysWithValues: (1...28).map { (day($0), met.contains($0) ? 400 : 0) })
    }

    private var allLogged: Set<Date> { Set((0...29).map(day)) }

    private func question(_ title: String, kind: FeelingKind = .scale, preset: FeelingPreset? = nil,
                          answers: [Int: Int]) -> FeelingTrends.Question {
        FeelingTrends.Question(title: title, kind: kind, preset: preset,
                               aboutNightBefore: preset?.isAboutNightBefore ?? false,
                               answers: Dictionary(uniqueKeysWithValues: answers.map { (day($0.key), $0.value) }))
    }

    private func state(_ questions: [FeelingTrends.Question], met: Set<Int>, goal: AnalyticsGoal? = nil,
                       logged: Set<Date>? = nil, counts: @escaping (Date) -> Bool = { _ in true },
                       totals customTotals: [Date: Double]? = nil) -> FeelingTrends.State? {
        FeelingTrends.state(totals: customTotals ?? totals(met: met), loggedDays: logged ?? allLogged,
                            questions: questions, goal: goal ?? atLeast400, counts: counts, today: today,
                            calendar: calendar)
    }

    /// Met on 1–20, missed on 21–28.
    private let met = Set(1...20)

    // MARK: - Readiness

    func testNoQuestionsIsNoState() {
        XCTAssertNil(state([], met: met))
    }

    func testGatheringUntilFourteenAnsweredDaysNamingTheClosest() {
        let energy = question("Energy", answers: Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 4) }))
        let mood = question("Mood", answers: Dictionary(uniqueKeysWithValues: (1...5).map { ($0, 4) }))
        XCTAssertEqual(state([mood, energy], met: met), .notEnoughData(question: "Energy", pairedDays: 9))
    }

    func testAQuestionAddedLaterDoesntHoldBackOneThatsReady() {
        // Energy: 4.5 on met days, 2 on missed ones, every day. Focus: three days so far.
        var energyAnswers: [Int: Int] = [:]
        for daysAgo in 1...28 { energyAnswers[daysAgo] = met.contains(daysAgo) ? (daysAgo.isMultiple(of: 2) ? 5 : 4) : 2 }
        let energy = question("Energy", answers: energyAnswers)
        let focus = question("Focus", answers: [1: 3, 2: 3, 3: 3])
        guard case .findings(let findings) = state([energy, focus], met: met) else { return XCTFail("no findings") }
        XCTAssertEqual(findings.map(\.question.title), ["Energy"])
        XCTAssertEqual(findings[0].first.days, 20)
        XCTAssertEqual(findings[0].second.days, 8)
        XCTAssertEqual(findings[0].first.average, 4.5, accuracy: 0.01)
        XCTAssertEqual(findings[0].second.average, 2)
    }

    func testDaysNotLoggedOrNotCountedDontPair() {
        let energy = question("Energy", answers: Dictionary(uniqueKeysWithValues: (1...28).map { ($0, 4) }))
        // Logged only 10 days: not enough, however many answers.
        XCTAssertEqual(state([energy], met: met, logged: Set((1...10).map(day))),
                       .notEnoughData(question: "Energy", pairedDays: 10))
        // Counted on 12 days only (a schedule, a course): not enough either.
        let counted = Set((1...12).map(day))
        XCTAssertEqual(state([energy], met: met, counts: { counted.contains($0) }),
                       .notEnoughData(question: "Energy", pairedDays: 12))
    }

    // MARK: - Findings

    func testASmallScaleGapIsNoPattern() {
        // 4 on met days, 3.6 (alternating 4 and 3, 3 more often) on missed ones: under half a point.
        var answers: [Int: Int] = [:]
        for daysAgo in 1...28 { answers[daysAgo] = met.contains(daysAgo) ? 4 : ([21, 23].contains(daysAgo) ? 3 : 4) }
        XCTAssertEqual(state([question("Energy", answers: answers)], met: met), .noPattern(checkedDays: 28))
    }

    func testEachSideNeedsFourDays() {
        // Missed on only 3 days: however different, no finding.
        var answers: [Int: Int] = [:]
        for daysAgo in 1...28 { answers[daysAgo] = daysAgo <= 25 ? 5 : 1 }
        XCTAssertEqual(state([question("Energy", answers: answers)], met: Set(1...25)), .noPattern(checkedDays: 28))
    }

    func testSleepPairsWithTheDayBefore() {
        // Sleep answered on day D is about the night after D − 1: 5 after met days, 2 after missed ones.
        var answers: [Int: Int] = [:]
        for answeredDaysAgo in 0...27 {
            let before = answeredDaysAgo + 1
            answers[answeredDaysAgo] = met.contains(before) ? 5 : 2
        }
        let sleep = question("Sleep last night", preset: .sleep, answers: answers)
        guard case .findings(let findings) = state([sleep], met: met) else { return XCTFail("no findings") }
        XCTAssertEqual(findings[0].first.average, 5)
        XCTAssertEqual(findings[0].second.average, 2)
        // Answers taken as the same day's would have mixed them up.
        XCTAssertEqual(FeelingTrends.answer(sleep, about: day(1), calendar: calendar), 5, "today's answer, about last night")
    }

    func testYesNoNeedsAQuarterOfTheDaysApart() {
        // Headache on 2 of 20 met days, 4 of 8 missed ones: 10% vs 50%.
        var answers: [Int: Int] = [:]
        for daysAgo in 1...28 { answers[daysAgo] = [3, 7].contains(daysAgo) || (21...24).contains(daysAgo) ? 1 : 0 }
        let headache = question("Headache", kind: .yesNo, preset: .headache, answers: answers)
        guard case .findings(let findings) = state([headache], met: met) else { return XCTFail("no findings") }
        XCTAssertEqual(findings[0].first.yesDays, 2)
        XCTAssertEqual(findings[0].second.yesDays, 4)
        XCTAssertEqual(findings[0].first.days, 20)

        // 2 of 20 against 2 of 8: 10% vs 25%, not enough.
        answers = [:]
        for daysAgo in 1...28 { answers[daysAgo] = [3, 7, 21, 22].contains(daysAgo) ? 1 : 0 }
        XCTAssertEqual(state([question("Headache", kind: .yesNo, answers: answers)], met: met),
                       .noPattern(checkedDays: 28))
    }

    func testAtMostTwoFindingsTheLargestFirst() {
        func scale(_ title: String, high: Int, low: Int) -> FeelingTrends.Question {
            question(title, answers: Dictionary(uniqueKeysWithValues: (1...28).map { ($0, met.contains($0) ? high : low) }))
        }
        let state = state([scale("Energy", high: 4, low: 3), scale("Mood", high: 5, low: 1),
                           scale("Focus", high: 5, low: 3)], met: met)
        guard case .findings(let findings) = state else { return XCTFail("no findings") }
        XCTAssertEqual(findings.map(\.question.title), ["Mood", "Focus"])
    }

    func testAnAtMostNutrientSplitsAtThreeQuartersOfItsLimit() {
        // Caffeine at most 400 mg: 350 mg on 1–20 (over 300), 100 mg on 21–28.
        let caffeineTotals = Dictionary(uniqueKeysWithValues: (1...28).map { (day($0), $0 <= 20 ? 350.0 : 100) })
        let atMost400 = AnalyticsGoal(goalType: .maximum, target: 400, upperBound: nil)
        var answers: [Int: Int] = [:]
        for answeredDaysAgo in 0...27 { answers[answeredDaysAgo] = answeredDaysAgo + 1 <= 20 ? 2 : 4 }
        let sleep = question("Sleep last night", preset: .sleep, answers: answers)
        guard case .findings(let findings) = state([sleep], met: [], goal: atMost400, totals: caffeineTotals) else {
            return XCTFail("no findings")
        }
        XCTAssertEqual(findings[0].threshold, 300)
        XCTAssertEqual(findings[0].first.average, 2, "over 300 mg")
        XCTAssertEqual(findings[0].second.average, 4)
    }

    // MARK: - Words

    func testTheSentences() {
        let text = FeelingTrendText(nutrientName: "Magnesium", unit: "mg", goal: atLeast400,
                                    locale: Locale(identifier: "en_GB"))
        let sleep = FeelingTrends.Finding(
            question: question("Sleep last night", preset: .sleep, answers: [:]),
            first: .init(average: 4.4, days: 17, yesDays: 0), second: .init(average: 2.5, days: 4, yesDays: 0),
            threshold: nil)
        XCTAssertEqual(text.sentence(sleep), "After days you reach your Magnesium goal, you rated your Sleep 4.4 on "
            + "average, vs 2.5 after other days.")
        XCTAssertEqual(text.labels(sleep).0, "Goal met")
        XCTAssertEqual(text.value(sleep.first, of: sleep), "4.4")
        XCTAssertEqual(text.basis(sleep), "Based on 17 days with the goal met and 4 days without.")

        let caffeine = FeelingTrendText(nutrientName: "Caffeine", unit: "mg",
                                        goal: AnalyticsGoal(goalType: .maximum, target: 400, upperBound: nil),
                                        locale: Locale(identifier: "en_GB"))
        let headache = FeelingTrends.Finding(
            question: question("Headache", kind: .yesNo, preset: .headache, answers: [:]),
            first: .init(average: 5.0 / 9, days: 9, yesDays: 5), second: .init(average: 2.0 / 15, days: 15, yesDays: 2),
            threshold: 300)
        XCTAssertEqual(caffeine.sentence(headache), "On days Caffeine passes 300 mg, you had a headache on 5 of 9 "
            + "days, vs 2 of 15 other days.")
        XCTAssertEqual(caffeine.labels(headache).0, "Over 300 mg")
        XCTAssertEqual(caffeine.value(headache.second, of: headache), "2 of 15")
        XCTAssertEqual(caffeine.noPattern, "No clear difference yet between days you come near your Caffeine limit "
            + "and other days.")

        let skin = FeelingTrends.Finding(
            question: question("Skin", kind: .yesNo, answers: [:]),
            first: .init(average: 0.5, days: 10, yesDays: 5), second: .init(average: 0.1, days: 10, yesDays: 1),
            threshold: nil)
        XCTAssertTrue(text.sentence(skin).contains("you answered yes to Skin on 5 of 10 days"))
        XCTAssertEqual(FeelingTrendText.progress(question: "Energy", pairedDays: 9), "Energy: 9 of 14 days")
    }

    /// Two devices answered the same day before syncing: the trends read the newest, as `FeelingAnswers` does.
    @MainActor
    func testTheNewestAnswerOfADayIsTheOneRead() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let energy = FeelingQuestion(title: "Energy", kind: .scale, presetRaw: "energy", sortOrder: 0)
        context.insert(energy)
        let older = FeelingAnswer(question: energy, day: day(2), value: 2)
        older.updatedAt = day(2).addingTimeInterval(3600)
        let newer = FeelingAnswer(question: energy, day: day(2).addingTimeInterval(60), value: 5)
        newer.updatedAt = day(2).addingTimeInterval(7200)
        context.insert(newer)
        context.insert(older)
        context.insert(FeelingAnswer(question: energy, day: day(3), value: 3))

        let question = FeelingTrends.Question(energy, calendar: calendar)
        XCTAssertEqual(question.answers[day(2)], 5)
        XCTAssertEqual(question.answers[day(3)], 3)
        XCTAssertEqual(question.answers.count, 2)
        XCTAssertFalse(question.aboutNightBefore)
    }

    // MARK: - The demo

    /// The App Store demo's Magnesium shows a Sleep pattern in its analytics.
    @MainActor
    func testTheDemosMagnesiumHasASleepPattern() throws {
        let container = try ModelContainer.inMemoryForTests()
        ScreenshotDemoData.replaceStore(in: container.mainContext)
        let magnesium = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<Nutrient>())
            .first { $0.name == "Magnesium" })
        let viewModel = NutrientAnalyticsViewModel(nutrient: magnesium, modelContext: container.mainContext)
        XCTAssertTrue(viewModel.feelingsInUse, "answers, though How you feel is off")
        guard case .findings(let findings) = viewModel.feelingState else {
            return XCTFail("no findings: \(String(describing: viewModel.feelingState))")
        }
        XCTAssertEqual(findings.first?.question.preset, .sleep)
        XCTAssertGreaterThan(findings[0].difference, 1)
    }
}
