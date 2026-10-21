import Foundation
import SwiftData

/// Welcome → first nutrient (DESIGN.md §5.8). Personal info isn't asked for any more — the profile starts empty
/// and name, birthday, weight and height are edited from Profile.
@Observable
final class OnboardingViewModel {
    enum Step {
        case welcome
        case firstNutrient
    }

    static let completedOnceKey = "nutrx.onboardingCompletedOnce"

    var step: Step = .welcome
    /// The starting point's editable values.
    let draft = NutrientDraft()
    private(set) var selectedStartingPoint: StartingPoint?
    /// Set once the "Something else" form has created a nutrient; onboarding finishes when its sheet is gone.
    private(set) var hasCustomNutrient = false

    var canStartTracking: Bool {
        selectedStartingPoint != nil && draft.isValid
    }

    func select(_ point: StartingPoint) {
        selectedStartingPoint = point
        point.fill(draft)
    }

    /// Creates `draft` in the General group and finishes onboarding.
    func startTracking(context: ModelContext, defaults: UserDefaults = .standard) {
        guard canStartTracking else { return }
        addNutrient(from: draft, context: context)
        complete(context: context, defaults: defaults)
    }

    /// Creates a nutrient from another draft ("Something else" → the blank form). Doesn't finish onboarding —
    /// `finishAfterCustomForm` does, once the form's sheet is gone, so the switch to the tabs doesn't happen under it.
    /// - Returns: whether a nutrient was created.
    @discardableResult
    func createCustomNutrient(from customDraft: NutrientDraft, context: ModelContext) -> Bool {
        guard customDraft.isValid else { return false }
        addNutrient(from: customDraft, context: context)
        hasCustomNutrient = true
        return true
    }

    /// The custom form's sheet was dismissed: finish onboarding if it created a nutrient (not on Cancel).
    func finishAfterCustomForm(context: ModelContext, defaults: UserDefaults = .standard) {
        guard hasCustomNutrient else { return }
        complete(context: context, defaults: defaults)
    }

    /// Marks onboarding done, creating the (empty) profile if there isn't one yet. Skip lands here directly.
    func complete(context: ModelContext, defaults: UserDefaults = .standard) {
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first ?? {
            let profile = UserProfile(name: "", birthdate: .distantPast, weight: 0, height: 0)
            context.insert(profile)
            return profile
        }()
        profile.onboardingCompleted = true
        try? context.save()
        defaults.set(true, forKey: Self.completedOnceKey)
        // A fresh install: this release's "What's new" card has nothing new to tell them (#148).
        WhatsNew.markSeenAtOnboarding(appVersion: Bundle.main.appVersion, defaults: defaults)
    }

    private func addNutrient(from draft: NutrientDraft, context: ModelContext) {
        let general = (try? context.fetch(FetchDescriptor<NutrientGroup>(predicate: #Predicate { $0.isSystem })))?.first
        let existing = (try? context.fetchCount(FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isRemoved }))) ?? 0
        _ = draft.insertNutrient(into: context, group: general, sortOrder: existing)
    }
}
