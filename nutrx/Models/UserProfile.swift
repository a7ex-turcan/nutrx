import Foundation
import SwiftData

@Model
final class UserProfile: @unchecked Sendable {
    var name: String
    var birthdate: Date
    var weight: Double
    var weightUnit: String
    var gender: String

    init(name: String, birthdate: Date, weight: Double, weightUnit: String = "kg", gender: String) {
        self.name = name
        self.birthdate = birthdate
        self.weight = weight
        self.weightUnit = weightUnit
        self.gender = gender
    }
}
