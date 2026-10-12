import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §3 — profile fields left onboarding, so every one of them is optional.
final class ProfileViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() {
        container = nil
    }

    private func load(_ profile: UserProfile) -> ProfileViewModel {
        context.insert(profile)
        let viewModel = ProfileViewModel()
        viewModel.load(context: context)
        return viewModel
    }

    private var emptyProfile: UserProfile {
        UserProfile(name: "", birthdate: .distantPast, weight: 0, height: 0, onboardingCompleted: true)
    }

    func testAnEmptyProfileLoadsAsBlankFields() {
        let viewModel = load(emptyProfile)
        XCTAssertEqual(viewModel.name, "")
        XCTAssertNil(viewModel.birthdate)
        XCTAssertEqual(viewModel.weight, "")
        XCTAssertEqual(viewModel.height, "")
        XCTAssertTrue(viewModel.isValid)
        XCTAssertFalse(viewModel.hasChanges)
    }

    func testANameAloneCanBeSaved() throws {
        let profile = emptyProfile
        let viewModel = load(profile)
        viewModel.name = " Sam "
        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertTrue(viewModel.isValid)
        viewModel.save()
        XCTAssertEqual(profile.name, "Sam")
        XCTAssertEqual(profile.weight, 0)
        XCTAssertEqual(profile.birthdate, .distantPast)
    }

    func testWeightAndHeightMustBePositiveNumbersWhenFilledIn() {
        let viewModel = load(emptyProfile)
        viewModel.weight = "abc"
        XCTAssertFalse(viewModel.isValid)
        viewModel.weight = "0"
        XCTAssertFalse(viewModel.isValid)
        viewModel.weight = (72.5).formattedAmount()
        XCTAssertTrue(viewModel.isValid)
        viewModel.height = "-3"
        XCTAssertFalse(viewModel.isValid)
    }

    func testSurroundingSpacesAreIgnoredWhenSaving() {
        let profile = emptyProfile
        let viewModel = load(profile)
        viewModel.weight = " \((72).formattedAmount()) "
        viewModel.height = "\((180).formattedAmount()) "
        XCTAssertTrue(viewModel.isValid)
        viewModel.save()
        XCTAssertEqual(profile.weight, 72)
        XCTAssertEqual(profile.height, 180)
    }

    func testRemovingTheBirthdayStoresNotSet() {
        let birthday = Calendar.current.date(byAdding: .year, value: -30, to: .now)!
        let profile = UserProfile(name: "Sam", birthdate: birthday, weight: 70, height: 180)
        let viewModel = load(profile)
        XCTAssertEqual(viewModel.birthdate, birthday)
        viewModel.birthdate = nil
        viewModel.save()
        XCTAssertEqual(profile.birthdate, .distantPast)
    }

    func testClearingWeightStoresZero() {
        let profile = UserProfile(name: "Sam", birthdate: .now, weight: 70, height: 180)
        let viewModel = load(profile)
        viewModel.weight = ""
        viewModel.save()
        XCTAssertEqual(profile.weight, 0)
        XCTAssertEqual(profile.height, 180)
    }
}
