import Foundation
import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    let container = try! ModelContainer(
        for: UserProfile.self, Nutrient.self, IntakeRecord.self, Exclusion.self, UserPreferences.self, NutrientReminder.self, NutrientGroup.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    // User profile
    let profile = UserProfile(
        name: "Alex",
        birthdate: Calendar.current.date(byAdding: .year, value: -28, to: .now)!,
        weight: 75,
        height: 180,
        onboardingCompleted: true
    )
    context.insert(profile)

    // Preferences (streaks enabled for preview)
    let preferences = UserPreferences()
    context.insert(preferences)

    // Groups
    let vitamins = NutrientGroup(name: "Vitamins", sortOrder: 0)
    let supplements = NutrientGroup(name: "Supplements", sortOrder: 1)
    let general = NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true)
    context.insert(vitamins)
    context.insert(supplements)
    context.insert(general)

    // Sample nutrients (createdAt set 10 days ago so streaks can compute)
    let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: .now)!

    let vitD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
    vitD.notes = "Take with fatty meal"
    vitD.group = vitamins
    vitD.groupSortOrder = 0
    vitD.createdAt = tenDaysAgo

    let omega3 = Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 2000, sortOrder: 1)
    omega3.notes = "Fish oil capsules"
    omega3.group = supplements
    omega3.groupSortOrder = 0
    omega3.createdAt = tenDaysAgo

    let caffeine = Nutrient(name: "Caffeine", unit: "mg", step: 100, dailyTarget: 400, sortOrder: 2)
    caffeine.notes = "Max 4 cups of coffee"
    caffeine.group = general
    caffeine.groupSortOrder = 0
    caffeine.createdAt = tenDaysAgo

    let water = Nutrient(name: "Water", unit: "cups", step: 1, dailyTarget: 8, sortOrder: 3)
    water.group = general
    water.groupSortOrder = 1
    water.createdAt = tenDaysAgo

    let protein = Nutrient(name: "Protein", unit: "g", step: 10, dailyTarget: 150, sortOrder: 4)
    protein.notes = "Include post-workout shake"
    protein.group = supplements
    protein.groupSortOrder = 1
    protein.createdAt = tenDaysAgo

    for nutrient in [vitD, omega3, caffeine, water, protein] {
        context.insert(nutrient)
    }

    // Some intake records for today to show progress
    context.insert(IntakeRecord(nutrient: vitD, amount: 1000))
    context.insert(IntakeRecord(nutrient: vitD, amount: 1000))
    context.insert(IntakeRecord(nutrient: omega3, amount: 500))
    context.insert(IntakeRecord(nutrient: omega3, amount: 500))
    context.insert(IntakeRecord(nutrient: omega3, amount: 500))
    context.insert(IntakeRecord(nutrient: omega3, amount: 500))
    context.insert(IntakeRecord(nutrient: caffeine, amount: 100))
    context.insert(IntakeRecord(nutrient: water, amount: 1))
    context.insert(IntakeRecord(nutrient: water, amount: 1))
    context.insert(IntakeRecord(nutrient: water, amount: 1))

    // Past day records for History preview
    // 5 consecutive days where all targets are met → 5-day streak
    let pastDays = (1...5).map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }

    for date in pastDays {
        // Vitamin D: 4×1000 = 4000 (target 4000) ✓
        for _ in 0..<4 { context.insert(IntakeRecord(nutrient: vitD, amount: 1000, date: date)) }
        // Omega-3: 4×500 = 2000 (target 2000) ✓
        for _ in 0..<4 { context.insert(IntakeRecord(nutrient: omega3, amount: 500, date: date)) }
        // Caffeine: 4×100 = 400 (target 400) ✓
        for _ in 0..<4 { context.insert(IntakeRecord(nutrient: caffeine, amount: 100, date: date)) }
        // Water: 8×1 = 8 (target 8) ✓
        for _ in 0..<8 { context.insert(IntakeRecord(nutrient: water, amount: 1, date: date)) }
        // Protein: 15×10 = 150 (target 150) ✓
        for _ in 0..<15 { context.insert(IntakeRecord(nutrient: protein, amount: 10, date: date)) }
    }

    // 6 days ago: incomplete day (breaks the streak, so best = current = 5)
    let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: .now)!
    context.insert(IntakeRecord(nutrient: vitD, amount: 1000, date: sixDaysAgo))
    context.insert(IntakeRecord(nutrient: water, amount: 1, date: sixDaysAgo))

    return container
}()
