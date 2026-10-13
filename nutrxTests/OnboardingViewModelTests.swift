import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §5.8 — finishing onboarding, with a starting point, a custom nutrient, or Skip.
final class OnboardingViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!
    private let suiteName = "OnboardingViewModelTests"

    override func setUpWithError() throws {
        container = try ModelContainer.inMemoryForTests()
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        container = nil
    }

    private func profiles() throws -> [UserProfile] { try context.fetch(FetchDescriptor<UserProfile>()) }
    private func nutrients() throws -> [Nutrient] { try context.fetch(FetchDescriptor<Nutrient>()) }

    func testNothingToStartWithoutAPick() {
        XCTAssertFalse(OnboardingViewModel().canStartTracking)
    }

    func testPickingFillsTheDraftButNeedsTheAmounts() {
        let viewModel = OnboardingViewModel()
        viewModel.select(StartingPoint.all[0])
        XCTAssertEqual(viewModel.selectedStartingPoint, StartingPoint.all[0])
        XCTAssertEqual(viewModel.draft.name, "Vitamin D")
        XCTAssertFalse(viewModel.canStartTracking)  // no goal or step yet

        viewModel.draft.dailyTarget = "2000"
        XCTAssertFalse(viewModel.canStartTracking)  // still no step
        viewModel.draft.step = "1000"
        XCTAssertTrue(viewModel.canStartTracking)
    }

    func testAnInvalidRangeBlocksStartTracking() {
        let viewModel = OnboardingViewModel()
        viewModel.select(StartingPoint.all[4])  // Protein, a range
        viewModel.draft.dailyTarget = "120"
        viewModel.draft.upperBound = "100"
        viewModel.draft.step = "20"
        XCTAssertNotNil(viewModel.draft.rangeError)
        XCTAssertFalse(viewModel.canStartTracking)
    }

    func testStartTrackingWithoutAmountsCreatesNothing() throws {
        let viewModel = OnboardingViewModel()
        viewModel.select(StartingPoint.all[0])
        viewModel.startTracking(context: context, defaults: defaults)
        XCTAssertTrue(try nutrients().isEmpty)
        XCTAssertTrue(try profiles().isEmpty)
    }

    func testStartTrackingCreatesTheEnteredNutrientInGeneralAndFinishes() throws {
        let viewModel = OnboardingViewModel()
        viewModel.select(StartingPoint.all[0])
        viewModel.draft.dailyTarget = "2000"
        viewModel.draft.step = "1000"
        viewModel.startTracking(context: context, defaults: defaults)

        let nutrient = try XCTUnwrap(nutrients().first)
        XCTAssertEqual(nutrient.name, "Vitamin D")
        XCTAssertEqual(nutrient.dailyTarget, 2000)
        XCTAssertEqual(nutrient.step, 1000)
        XCTAssertEqual(nutrient.tint, .amber)
        XCTAssertEqual(nutrient.symbolName, "sun.max")
        XCTAssertEqual(nutrient.group?.isSystem, true)

        let profile = try XCTUnwrap(profiles().first)
        XCTAssertTrue(profile.onboardingCompleted)
        XCTAssertTrue(defaults.bool(forKey: OnboardingViewModel.completedOnceKey))
    }

    func testSkipFinishesWithAnEmptyProfileAndNoNutrient() throws {
        OnboardingViewModel().complete(context: context, defaults: defaults)

        XCTAssertTrue(try nutrients().isEmpty)
        let profile = try XCTUnwrap(profiles().first)
        XCTAssertTrue(profile.onboardingCompleted)
        XCTAssertEqual(profile.name, "")
        XCTAssertEqual(profile.weight, 0)
        XCTAssertEqual(profile.birthdate, .distantPast)
    }

    func testFinishingReusesAnExistingProfile() throws {
        context.insert(UserProfile(name: "Alex", birthdate: .now, weight: 70, height: 180))
        OnboardingViewModel().complete(context: context, defaults: defaults)

        XCTAssertEqual(try profiles().count, 1)
        XCTAssertEqual(try profiles().first?.name, "Alex")
        XCTAssertEqual(try profiles().first?.onboardingCompleted, true)
    }

    func testSomethingElseCreatesTheCustomNutrientWithoutFinishing() throws {
        let custom = NutrientDraft()
        custom.name = "Iron"
        custom.unit = "mg"
        custom.dailyTarget = "18"
        custom.step = "6"
        let viewModel = OnboardingViewModel()
        XCTAssertTrue(viewModel.createCustomNutrient(from: custom, context: context))

        XCTAssertEqual(try nutrients().map(\.name), ["Iron"])
        XCTAssertTrue(try profiles().isEmpty)  // not finished while the form's sheet is up

        viewModel.finishAfterCustomForm(context: context, defaults: defaults)
        XCTAssertEqual(try profiles().first?.onboardingCompleted, true)
    }

    func testCancellingTheCustomFormDoesNotFinish() throws {
        OnboardingViewModel().finishAfterCustomForm(context: context, defaults: defaults)
        XCTAssertTrue(try profiles().isEmpty)
    }

    func testAnInvalidCustomDraftCreatesNothing() throws {
        XCTAssertFalse(OnboardingViewModel().createCustomNutrient(from: NutrientDraft(), context: context))
        XCTAssertTrue(try nutrients().isEmpty)
    }
}
