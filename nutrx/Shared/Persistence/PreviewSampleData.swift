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

    // Groups
    let vitamins = NutrientGroup(name: "Vitamins", sortOrder: 0)
    let supplements = NutrientGroup(name: "Supplements", sortOrder: 1)
    let general = NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true)
    context.insert(vitamins)
    context.insert(supplements)
    context.insert(general)

    // Sample nutrients
    let vitD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
    vitD.group = vitamins
    vitD.groupSortOrder = 0

    let omega3 = Nutrient(name: "Omega-3", unit: "mg", step: 500, dailyTarget: 2000, sortOrder: 1)
    omega3.group = supplements
    omega3.groupSortOrder = 0

    let caffeine = Nutrient(name: "Caffeine", unit: "mg", step: 100, dailyTarget: 400, sortOrder: 2)
    caffeine.group = general
    caffeine.groupSortOrder = 0

    let water = Nutrient(name: "Water", unit: "cups", step: 1, dailyTarget: 8, sortOrder: 3)
    water.group = general
    water.groupSortOrder = 1

    let protein = Nutrient(name: "Protein", unit: "g", step: 10, dailyTarget: 150, sortOrder: 4)
    protein.group = supplements
    protein.groupSortOrder = 1

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
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!

    for date in [yesterday, twoDaysAgo] {
        context.insert(IntakeRecord(nutrient: vitD, amount: 1000, date: date))
        context.insert(IntakeRecord(nutrient: vitD, amount: 1000, date: date))
        context.insert(IntakeRecord(nutrient: vitD, amount: 1000, date: date))
        context.insert(IntakeRecord(nutrient: omega3, amount: 500, date: date))
        context.insert(IntakeRecord(nutrient: omega3, amount: 500, date: date))
        context.insert(IntakeRecord(nutrient: caffeine, amount: 100, date: date))
        context.insert(IntakeRecord(nutrient: caffeine, amount: 100, date: date))
        context.insert(IntakeRecord(nutrient: water, amount: 1, date: date))
        context.insert(IntakeRecord(nutrient: water, amount: 1, date: date))
        context.insert(IntakeRecord(nutrient: water, amount: 1, date: date))
        context.insert(IntakeRecord(nutrient: water, amount: 1, date: date))
        context.insert(IntakeRecord(nutrient: protein, amount: 10, date: date))
        context.insert(IntakeRecord(nutrient: protein, amount: 10, date: date))
    }

    return container
}()
