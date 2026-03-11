import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var birthdate: Date
    var weight: Double
    var weightUnit: String
    var height: Double
    var heightUnit: String
    var onboardingCompleted: Bool

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
