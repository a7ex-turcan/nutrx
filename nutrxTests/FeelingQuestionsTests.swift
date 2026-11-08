import XCTest
import SwiftData
@testable import nutrx

/// How you feel's questions (#133, docs/pro/HOW-YOU-FEEL.md §1, §6): the starting presets, turning presets on and
/// off, the user's own (titles, the limit, kinds), the order, and merging a preset two devices both turned on.
@MainActor
final class FeelingQuestionsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func titles() -> [String] {
        FeelingQuestions.active(in: context).map(\.displayTitle)
    }

    private func answer(_ question: FeelingQuestion, value: Int, daysAgo: Int = 0) {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: .now))!
        context.insert(FeelingAnswer(question: question, day: day, value: value))
        try? context.save()
    }

    // MARK: - Presets

    func testTurningOnTheFirstTimeAddsEnergyMoodAndSleep() {
        FeelingQuestions.setUpIfNeeded(in: context)
        XCTAssertEqual(titles(), ["Energy", "Mood", "Sleep last night"])
        XCTAssertEqual(FeelingQuestions.active(in: context).map(\.kind), [.scale, .scale, .scale])
    }

    func testTurningOnAgainKeepsWhatTheUserChoseEvenNone() {
        FeelingQuestions.setUpIfNeeded(in: context)
        for question in FeelingQuestions.active(in: context) {
            FeelingQuestions.remove(question, in: context)
        }
        FeelingQuestions.setUpIfNeeded(in: context)
        XCTAssertEqual(titles(), [])
    }

    func testAPresetGoesToTheEndAndComesBackWithItsAnswers() {
        FeelingQuestions.setUpIfNeeded(in: context)
        let energy = FeelingQuestions.active(in: context)[0]
        answer(energy, value: 4)
        FeelingQuestions.remove(energy, in: context)
        XCTAssertEqual(titles(), ["Mood", "Sleep last night"])
        XCTAssertEqual(FeelingQuestions.presetsToAdd(besides: FeelingQuestions.active(in: context)).first, .energy)

        let back = FeelingQuestions.add(.energy, in: context)
        XCTAssertTrue(back === energy, "the same question, not a new one")
        XCTAssertEqual(titles(), ["Mood", "Sleep last night", "Energy"])
        XCTAssertEqual(back.answers?.map(\.value), [4])
        XCTAssertEqual(FeelingQuestions.all(in: context).count, 3)
    }

    func testAddingAPresetThatsOnDoesNothing() {
        FeelingQuestions.setUpIfNeeded(in: context)
        FeelingQuestions.add(.mood, in: context)
        XCTAssertEqual(titles(), ["Energy", "Mood", "Sleep last night"])
    }

    func testPresetsToAddFollowThePresetsOrder() {
        FeelingQuestions.setUpIfNeeded(in: context)
        XCTAssertEqual(FeelingQuestions.presetsToAdd(besides: FeelingQuestions.active(in: context)),
                       [.focus, .stress, .digestion, .headache, .aches])
    }

    func testPresetWords() {
        XCTAssertEqual(FeelingPreset.headache.kind, .yesNo)
        XCTAssertEqual(FeelingPreset.aches.title, "Aches or pains")
        XCTAssertTrue(FeelingPreset.sleep.ends == ("Poor", "Great"))
        XCTAssertTrue(FeelingPreset.sleep.isAboutNightBefore)
        XCTAssertFalse(FeelingPreset.energy.isAboutNightBefore)
        // The stored raw values: renaming one would orphan every question made from it.
        XCTAssertEqual(FeelingPreset.allCases.map(\.rawValue),
                       ["energy", "mood", "sleep", "focus", "stress", "digestion", "headache", "aches"])
    }

    // MARK: - The user's own

    func testOwnQuestionsAreTrimmedCappedAndNeverDuplicated() {
        FeelingQuestions.setUpIfNeeded(in: context)
        XCTAssertEqual(FeelingQuestions.problem(with: "   ", in: context), .empty)
        XCTAssertEqual(FeelingQuestions.problem(with: "energy", in: context), .duplicate)
        XCTAssertEqual(FeelingQuestions.problem(with: "SLEEP LAST NIGHT", in: context), .duplicate)
        XCTAssertNil(FeelingQuestions.addOwn(title: " Mood ", kind: .scale, in: context))

        let skin = FeelingQuestions.addOwn(title: "  Skin  ", kind: .yesNo, in: context)
        XCTAssertEqual(skin?.title, "Skin")
        XCTAssertNil(skin?.preset)
        XCTAssertEqual(titles(), ["Energy", "Mood", "Sleep last night", "Skin"])

        let long = String(repeating: "a", count: 60)
        XCTAssertEqual(FeelingQuestions.addOwn(title: long, kind: .scale, in: context)?.title.count,
                       FeelingQuestions.titleLimit)
    }

    func testAtMostFiveOfYourOwnAndRemovedOnesDontCount() {
        for index in 1...5 {
            XCTAssertNotNil(FeelingQuestions.addOwn(title: "Q\(index)", kind: .scale, in: context))
        }
        XCTAssertFalse(FeelingQuestions.canAddOwn(in: context))
        XCTAssertNil(FeelingQuestions.addOwn(title: "Q6", kind: .scale, in: context))
        XCTAssertEqual(FeelingQuestions.ownCount(of: FeelingQuestions.active(in: context)), 5)

        // Presets don't count toward the five.
        FeelingQuestions.add(.energy, in: context)
        FeelingQuestions.remove(FeelingQuestions.active(in: context)[0], in: context)
        XCTAssertTrue(FeelingQuestions.canAddOwn(in: context))
        XCTAssertNotNil(FeelingQuestions.addOwn(title: "Q6", kind: .scale, in: context))
    }

    func testAddingARemovedOwnQuestionAgainBringsItsAnswersBack() {
        let skin = FeelingQuestions.addOwn(title: "Skin", kind: .scale, in: context)!
        answer(skin, value: 2)
        FeelingQuestions.remove(skin, in: context)

        let again = FeelingQuestions.addOwn(title: "skin", kind: .scale, in: context)
        XCTAssertTrue(again === skin)
        XCTAssertEqual(again?.title, "skin")
        XCTAssertEqual(again?.answers?.count, 1)

        // Another kind is another question.
        FeelingQuestions.remove(skin, in: context)
        let yesNo = FeelingQuestions.addOwn(title: "Skin", kind: .yesNo, in: context)
        XCTAssertFalse(yesNo === skin)
    }

    func testRenamingIsForYourOwnOnly() {
        FeelingQuestions.setUpIfNeeded(in: context)
        let energy = FeelingQuestions.active(in: context)[0]
        XCTAssertFalse(FeelingQuestions.rename(energy, to: "Vigour", in: context))
        XCTAssertEqual(energy.displayTitle, "Energy")

        let skin = FeelingQuestions.addOwn(title: "Skin", kind: .scale, in: context)!
        XCTAssertFalse(FeelingQuestions.rename(skin, to: "Mood", in: context), "taken")
        XCTAssertTrue(FeelingQuestions.rename(skin, to: "SKIN", in: context), "its own title, recased")
        XCTAssertTrue(FeelingQuestions.rename(skin, to: "Skin feel ", in: context))
        XCTAssertEqual(skin.title, "Skin feel")
    }

    func testTheKindChangesOnlyBeforeAnswers() {
        let skin = FeelingQuestions.addOwn(title: "Skin", kind: .scale, in: context)!
        XCTAssertTrue(FeelingQuestions.setKind(.yesNo, of: skin, in: context))
        XCTAssertEqual(skin.kind, .yesNo)
        answer(skin, value: 1)
        XCTAssertFalse(FeelingQuestions.canChangeKind(of: skin))
        XCTAssertFalse(FeelingQuestions.setKind(.scale, of: skin, in: context))
        XCTAssertEqual(skin.kind, .yesNo)

        let energy = FeelingQuestions.add(.energy, in: context)
        XCTAssertFalse(FeelingQuestions.canChangeKind(of: energy), "a preset's kind is the preset's")
    }

    // MARK: - Order

    func testMovingReordersTheCardAndKeepsRemovedOnesAfter() {
        FeelingQuestions.setUpIfNeeded(in: context)
        FeelingQuestions.add(.focus, in: context)
        FeelingQuestions.remove(FeelingQuestions.active(in: context)[1], in: context)  // Mood
        XCTAssertEqual(titles(), ["Energy", "Sleep last night", "Focus"])

        // Focus to the top, as a drag from the last row to the first.
        FeelingQuestions.move(fromOffsets: [2], toOffset: 0, in: context)
        XCTAssertEqual(titles(), ["Focus", "Energy", "Sleep last night"])

        // Energy below Sleep: the list's move puts it before what was at the destination.
        FeelingQuestions.move(fromOffsets: [1], toOffset: 3, in: context)
        XCTAssertEqual(titles(), ["Focus", "Sleep last night", "Energy"])

        XCTAssertEqual(FeelingQuestions.all(in: context).map(\.displayTitle),
                       ["Focus", "Sleep last night", "Energy", "Mood"])
    }

    // MARK: - Two devices

    func testAPresetBothDevicesTurnedOnIsMergedIntoTheOldest() {
        let older = FeelingQuestion(title: "Energy", kind: .scale, presetRaw: "energy", sortOrder: 0)
        older.createdAt = Date(timeIntervalSinceNow: -60)
        older.isRemoved = true
        let newer = FeelingQuestion(title: "Energy", kind: .scale, presetRaw: "energy", sortOrder: 4)
        context.insert(older)
        context.insert(newer)
        answer(older, value: 3, daysAgo: 1)
        answer(newer, value: 5)

        XCTAssertTrue(FeelingQuestions.mergeDuplicatePresets(in: context))
        let all = FeelingQuestions.all(in: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0] === older)
        XCTAssertFalse(older.isRemoved, "on, since the other device had it on")
        XCTAssertEqual(Set(older.answers?.map(\.value) ?? []), [3, 5])
        XCTAssertFalse(FeelingQuestions.mergeDuplicatePresets(in: context), "nothing left to merge")
    }

    func testTheUsersOwnAreNeverMerged() {
        FeelingQuestions.addOwn(title: "Skin", kind: .scale, in: context)
        context.insert(FeelingQuestion(title: "Skin", kind: .scale, sortOrder: 1))
        XCTAssertFalse(FeelingQuestions.mergeDuplicatePresets(in: context))
        XCTAssertEqual(FeelingQuestions.all(in: context).count, 2)
    }

    // MARK: - Words

    func testCaptions() {
        XCTAssertEqual(FeelingText.caption(kind: .scale, ends: FeelingPreset.mood.ends), "1 to 5 · Poor to Great")
        XCTAssertEqual(FeelingText.caption(kind: .scale, ends: FeelingPreset.energy.ends), "1 to 5 · Low to High")
        XCTAssertEqual(FeelingText.kindExplanation(.yesNo), "Answered with Yes or No.")
        XCTAssertEqual(FeelingText.caption(kind: .yesNo, ends: ("Low", "High")), "Yes or no")
        XCTAssertEqual(FeelingText.addFooter(ownCount: 5), "You have 5 of your own. Remove one to add another.")
        XCTAssertEqual(FeelingText.titleProblem(.duplicate), "You already have a question called that.")
        XCTAssertNil(FeelingText.titleProblem(.empty))
        XCTAssertEqual(FeelingText.kindLocked(.yesNo), "It has answers, so it stays yes or no.")
    }
}
