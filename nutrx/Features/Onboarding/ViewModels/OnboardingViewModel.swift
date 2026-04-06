import Foundation
import SwiftData

@Observable
final class OnboardingViewModel {
    var name: String = ""
    var birthdate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    var weight: String = ""
    var weightUnit: String = "kg"
    var height: String = ""
    var heightUnit: String = "cm"

    var isPersonalInfoValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (weight.parsedDouble ?? 0) > 0
            && (height.parsedDouble ?? 0) > 0
    }

    func saveProfile(context: ModelContext) {
        guard let weightValue = weight.parsedDouble,
              let heightValue = height.parsedDouble else { return }

        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            birthdate: birthdate,
            weight: weightValue,
            weightUnit: weightUnit,
            height: heightValue,
            heightUnit: heightUnit,
            onboardingCompleted: false
        )
        context.insert(profile)
    }

    func completeOnboarding(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else { return }
        profile.onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "nutrx.onboardingCompletedOnce")
    }
}
