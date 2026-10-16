import SwiftData
import XCTest
@testable import nutrx

/// The create sheet's choices: which nutrients start in the report, and what the period and toggles change.
final class ReportViewModelTests: XCTestCase {
    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: .now))!
            .addingTimeInterval(9 * 3600)
    }

    func testANutrientNeverLoggedInThePeriodStartsOut() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        let zinc = Nutrient(name: "Zinc", unit: "mg", step: 10, dailyTarget: 10, sortOrder: 1)
        for nutrient in [vitaminD, zinc] {
            nutrient.createdAt = daysAgo(60)
            context.insert(nutrient)
        }
        for day in 1...10 {
            context.insert(IntakeRecord(nutrient: vitaminD, amount: 4000, date: daysAgo(day), note: day == 2 ? "New bottle" : nil))
        }
        context.insert(UserProfile(name: "Alex", birthdate: .distantPast, weight: 0, height: 0, onboardingCompleted: true))
        try context.save()

        let viewModel = ReportViewModel()
        viewModel.load(context: context)
        XCTAssertEqual(viewModel.candidates.map(\.name), ["Vitamin D", "Zinc"])
        XCTAssertEqual(viewModel.nutrientsValue, "1 of 2", "Zinc has no entries, so it starts unchecked")
        XCTAssertEqual(viewModel.report?.sections.map(\.name), ["Vitamin D"])
        XCTAssertEqual(viewModel.report?.overallHitRate, 1)
        XCTAssertEqual(viewModel.report?.name, "Alex")
        XCTAssertEqual(viewModel.report?.notes.map(\.text), ["New bottle"])

        let zincCandidate = try XCTUnwrap(viewModel.candidates.last)
        viewModel.toggle(zincCandidate)
        XCTAssertEqual(viewModel.nutrientsValue, "All 2")
        XCTAssertEqual(viewModel.report?.sections.map(\.name), ["Vitamin D", "Zinc"])

        viewModel.includesName = false
        viewModel.includesNotes = false
        XCTAssertNil(viewModel.report?.name)
        XCTAssertEqual(viewModel.report?.notes, [])
        viewModel.period = .days30
        XCTAssertEqual(viewModel.report?.dayCount, 30)
        XCTAssertTrue(viewModel.canCreate)
    }
}
