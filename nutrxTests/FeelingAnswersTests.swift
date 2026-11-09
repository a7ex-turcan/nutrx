import XCTest
import SwiftData
@testable import nutrx

/// How you feel's answers (#133, docs/pro/HOW-YOU-FEEL.md §2, §6): one per question and day, the newest read; when
/// Today's card shows; which History days can change; the folded card's line.
@MainActor
final class FeelingAnswersTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Chisinau")!
        return calendar
    }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func setUpQuestions() -> (energy: FeelingQuestion, headache: FeelingQuestion) {
        FeelingQuestions.setUpIfNeeded(in: context)
        let energy = FeelingQuestions.active(in: context)[0]
        let headache = FeelingQuestions.add(.headache, in: context)!
        return (energy, headache)
    }

    // MARK: - Answers

    func testSettingChangingAndClearingADaysAnswer() {
        let (energy, _) = setUpQuestions()
        FeelingAnswers.set(4, for: energy, on: at(8, 20), in: context, calendar: calendar)
        XCTAssertEqual(FeelingAnswers.value(for: energy, on: at(8, 9), calendar: calendar), 4, "any time that day")
        XCTAssertNil(FeelingAnswers.value(for: energy, on: at(7, 20), calendar: calendar))

        FeelingAnswers.set(2, for: energy, on: at(8, 21), in: context, calendar: calendar)
        XCTAssertEqual(FeelingAnswers.value(for: energy, on: at(8, 9), calendar: calendar), 2)
        XCTAssertEqual(energy.answers?.count, 1, "changed, not added")
        XCTAssertEqual(energy.answers?.first?.day, calendar.startOfDay(for: at(8, 21)))

        FeelingAnswers.set(nil, for: energy, on: at(8, 22), in: context, calendar: calendar)
        XCTAssertNil(FeelingAnswers.value(for: energy, on: at(8, 9), calendar: calendar))
        XCTAssertEqual(energy.answers?.count, 0)
    }

    /// Two devices answered the same day before syncing: the newest is read, and the next change keeps one.
    func testTheNewestOfTwoDevicesAnswersIsRead() {
        let (energy, _) = setUpQuestions()
        let day = calendar.startOfDay(for: at(8, 20))
        let older = FeelingAnswer(question: energy, day: day, value: 2)
        older.updatedAt = at(8, 19)
        let newer = FeelingAnswer(question: energy, day: day, value: 5)
        newer.updatedAt = at(8, 20)
        context.insert(newer)
        context.insert(older)
        try? context.save()
        XCTAssertEqual(FeelingAnswers.value(for: energy, on: day, calendar: calendar), 5)

        FeelingAnswers.set(3, for: energy, on: day, in: context, calendar: calendar)
        XCTAssertEqual(energy.answers?.map(\.value), [3])
    }

    func testValuesAndComplete() {
        let (energy, headache) = setUpQuestions()
        let questions = FeelingQuestions.active(in: context)  // Energy, Mood, Sleep, Headache
        FeelingAnswers.set(4, for: energy, on: at(8, 20), in: context, calendar: calendar)
        FeelingAnswers.set(0, for: headache, on: at(8, 20), in: context, calendar: calendar)
        var values = FeelingAnswers.values(for: questions, on: at(8, 20), calendar: calendar)
        XCTAssertEqual(values.count, 2)
        XCTAssertFalse(FeelingAnswers.isComplete(questions, values: values))

        for question in questions where values[question.persistentModelID] == nil {
            FeelingAnswers.set(3, for: question, on: at(8, 20), in: context, calendar: calendar)
        }
        values = FeelingAnswers.values(for: questions, on: at(8, 20), calendar: calendar)
        XCTAssertTrue(FeelingAnswers.isComplete(questions, values: values))
        XCTAssertFalse(FeelingAnswers.isComplete([], values: values), "nothing to answer isn't done")
    }

    // MARK: - Today's card

    func testTheCardShowsFromTheAskFromTimeUntilTheDayEnds() {
        func shows(at now: Date, enabled: Bool = true, questions: Bool = true, hiddenDay: Date? = nil) -> Bool {
            FeelingAnswers.cardShows(enabled: enabled, hasQuestions: questions, askMinutes: 19 * 60,
                                     hiddenDay: hiddenDay, now: now, calendar: calendar)
        }
        XCTAssertFalse(shows(at: at(8, 18, 59)))
        XCTAssertTrue(shows(at: at(8, 19)))
        XCTAssertTrue(shows(at: at(8, 23, 59)))
        XCTAssertFalse(shows(at: at(9, 0, 30)), "a new day starts before its ask time")
        XCTAssertFalse(shows(at: at(8, 20), enabled: false))
        XCTAssertFalse(shows(at: at(8, 20), questions: false))
        XCTAssertFalse(shows(at: at(8, 20), hiddenDay: calendar.startOfDay(for: at(8, 1))), "hidden today")
        XCTAssertTrue(shows(at: at(9, 20), hiddenDay: calendar.startOfDay(for: at(8, 1))), "back the next day")
    }

    // MARK: - The reminder

    func testTheReminderIsTodayAtTheAskFromTimeUnlessAnsweredOrPast() {
        func date(at now: Date, answered: Bool = false) -> Date {
            FeelingAnswers.reminderDate(askMinutes: 19 * 60, answeredToday: answered, now: now, calendar: calendar)
        }
        XCTAssertEqual(date(at: at(8, 12)), at(8, 19))
        XCTAssertEqual(date(at: at(8, 12), answered: true), at(9, 19), "checked in already: tomorrow")
        XCTAssertEqual(date(at: at(8, 19)), at(9, 19), "the time has come: tomorrow's")
        XCTAssertEqual(date(at: at(8, 23, 30)), at(9, 19))
    }

    func testTheRemindersBodyNamesUpToThreeQuestions() {
        let locale = Locale(identifier: "en_GB")
        XCTAssertEqual(FeelingText.reminderBody(["Energy"], locale: locale), "Check in on Energy.")
        XCTAssertEqual(FeelingText.reminderBody(["Energy", "Mood", "Sleep last night"], locale: locale),
                       "Check in on Energy, Mood and Sleep last night.")
        XCTAssertEqual(FeelingText.reminderBody(["Energy", "Mood", "Focus", "Stress", "Skin"], locale: locale),
                       "Check in on Energy, Mood, Focus and 2 more.")
    }

    // MARK: - History

    func testTodayAndTheSevenDaysBeforeCanBeEdited() {
        XCTAssertTrue(FeelingAnswers.isEditable(at(8, 9), today: at(8, 22), calendar: calendar))
        XCTAssertTrue(FeelingAnswers.isEditable(at(1, 9), today: at(8, 22), calendar: calendar))
        XCTAssertFalse(FeelingAnswers.isEditable(at(1, 9), today: at(9, 0, 10), calendar: calendar))
        XCTAssertFalse(FeelingAnswers.isEditable(at(9, 9), today: at(8, 22), calendar: calendar), "not tomorrow")
    }

    func testFirstDayIsTheFirstQuestions() {
        XCTAssertNil(FeelingAnswers.firstDay(of: [], calendar: calendar))
        let (energy, headache) = setUpQuestions()
        energy.createdAt = at(3, 20)
        headache.createdAt = at(6, 8)
        XCTAssertEqual(FeelingAnswers.firstDay(of: [headache, energy], calendar: calendar),
                       calendar.startOfDay(for: at(3, 20)))
    }

    // MARK: - Words

    func testTheFoldedLineAndAnswers() {
        let (energy, headache) = setUpQuestions()
        let questions = [energy, headache]
        let values = [energy.persistentModelID: 4, headache.persistentModelID: 0]
        XCTAssertEqual(FeelingText.summary(questions, values: values), "Energy 4 · Headache no")
        XCTAssertEqual(FeelingText.checkedIn(questions, values: values), "Checked in · Energy 4 · Headache no")
        XCTAssertEqual(FeelingText.summary(questions, values: [energy.persistentModelID: 2]), "Energy 2")
        XCTAssertEqual(FeelingText.answer(1, kind: .yesNo), "Yes")
        XCTAssertEqual(FeelingText.scaleValue(nil), "Not answered")
        XCTAssertEqual(FeelingText.scaleValue(3), "3 of 5")
    }
}
