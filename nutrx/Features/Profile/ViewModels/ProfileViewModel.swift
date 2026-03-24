import Foundation
import SwiftData

@Observable
final class ProfileViewModel {
    var name: String = ""
    var birthdate: Date = .now
    var weight: String = ""
    var weightUnit: String = "kg"
    var height: String = ""
    var heightUnit: String = "cm"

    private var profile: UserProfile?

    var hasChanges: Bool {
        guard let profile else { return false }
        return name != profile.name
            || birthdate != profile.birthdate
            || weight != formattedValue(profile.weight)
            || weightUnit != profile.weightUnit
            || height != formattedValue(profile.height)
            || heightUnit != profile.heightUnit
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (weight.parsedDouble ?? 0) > 0
            && (height.parsedDouble ?? 0) > 0
    }

    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else { return }
        self.profile = profile
        name = profile.name
        birthdate = profile.birthdate
        weight = formattedValue(profile.weight)
        weightUnit = profile.weightUnit
        height = formattedValue(profile.height)
        heightUnit = profile.heightUnit
    }

    func save() {
        guard let profile,
              let weightValue = weight.parsedDouble,
              let heightValue = height.parsedDouble else { return }

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.birthdate = birthdate
        profile.weight = weightValue
        profile.weightUnit = weightUnit
        profile.height = heightValue
        profile.heightUnit = heightUnit
    }

    private func formattedValue(_ value: Double) -> String {
        value.displayString
    }
}
