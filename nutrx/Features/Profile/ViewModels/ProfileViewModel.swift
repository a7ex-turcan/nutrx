import Foundation
import SwiftData

/// Edits the profile. Every field is optional — onboarding no longer asks for them (DESIGN.md §3), so a profile
/// can be empty; `UserProfile` stores "not set" as an empty name, `Date.distantPast` and 0.
@Observable
final class ProfileViewModel {
    var name: String = ""
    /// nil = not set.
    var birthdate: Date?
    var weight: String = ""
    var weightUnit: String = "kg"
    var height: String = ""
    var heightUnit: String = "cm"
    var profileImageData: Data?

    private var profile: UserProfile?

    var hasChanges: Bool {
        guard let profile else { return false }
        return name != profile.name
            || birthdate != Self.storedBirthdate(profile.birthdate)
            || weight != formattedValue(profile.weight)
            || weightUnit != profile.weightUnit
            || height != formattedValue(profile.height)
            || heightUnit != profile.heightUnit
            || profileImageData != profile.profileImageData
    }

    /// Weight and height may be blank; if filled in they must be positive numbers.
    var isValid: Bool {
        Self.isBlankOrPositive(weight) && Self.isBlankOrPositive(height)
    }

    /// A birthday to start the picker on when the user adds one.
    static let suggestedBirthdate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now

    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else { return }
        self.profile = profile
        name = profile.name
        birthdate = Self.storedBirthdate(profile.birthdate)
        weight = formattedValue(profile.weight)
        weightUnit = profile.weightUnit
        height = formattedValue(profile.height)
        heightUnit = profile.heightUnit
        profileImageData = profile.profileImageData
    }

    func save() {
        guard let profile, isValid else { return }

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.birthdate = birthdate ?? .distantPast
        profile.weight = weight.parsedDouble ?? 0
        profile.weightUnit = weightUnit
        profile.height = height.parsedDouble ?? 0
        profile.heightUnit = heightUnit
        profile.profileImageData = profileImageData
    }

    /// 0 means "not set", shown as an empty field.
    private func formattedValue(_ value: Double) -> String {
        value > 0 ? value.displayString : ""
    }

    private static func storedBirthdate(_ date: Date) -> Date? {
        date == .distantPast ? nil : date
    }

    private static func isBlankOrPositive(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        guard let value = trimmed.parsedDouble else { return false }
        return value > 0
    }
}
