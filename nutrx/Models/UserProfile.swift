import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    var birthdate: Date = Date.distantPast
    var weight: Double = 0
    var weightUnit: String = "kg"
    var height: Double = 0
    var heightUnit: String = "cm"
    var onboardingCompleted: Bool = false

    init(
        name: String,
        birthdate: Date,
        weight: Double,
        weightUnit: String = "kg",
        height: Double,
        heightUnit: String = "cm",
        onboardingCompleted: Bool = false
    ) {
        self.name = name
        self.birthdate = birthdate
        self.weight = weight
        self.weightUnit = weightUnit
        self.height = height
        self.heightUnit = heightUnit
        self.onboardingCompleted = onboardingCompleted
    }
}
