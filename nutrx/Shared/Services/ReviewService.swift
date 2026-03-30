import Foundation
import StoreKit
import SwiftData
import UIKit

enum ReviewService {

    /// Call after every intake action. Evaluates guard conditions and fires the review prompt if they pass.
    static func maybeRequestReview(
        context: ModelContext,
        currentStreak: Int,
        totalIntakeCount: Int
    ) {
        guard shouldPrompt(context: context, currentStreak: currentStreak, totalIntakeCount: totalIntakeCount) else { return }

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
            recordPrompt(context: context)
        }
    }

    // MARK: - Private

    private static func shouldPrompt(
        context: ModelContext,
        currentStreak: Int,
        totalIntakeCount: Int
    ) -> Bool {
        guard let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first else { return false }

        // Guard: version already prompted
        let currentVersion = Bundle.main.appVersion
        if prefs.lastReviewRequestedVersion == currentVersion { return false }

        // Guard: prompted too recently (90-day cooldown)
        if let lastDate = prefs.lastReviewRequestedDate,
           Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0 < 90 {
            return false
        }

        // Guard: account too new (< 3 days)
        if let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: profile.createdAt, to: .now).day ?? 0
            if daysSinceCreation < 3 { return false }
        }

        // Trigger: streak milestone
        if [3, 7, 14].contains(currentStreak) { return true }

        // Trigger: intake volume crossed 30
        if totalIntakeCount == 30 { return true }

        return false
    }

    private static func recordPrompt(context: ModelContext) {
        guard let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first else { return }
        prefs.lastReviewRequestedVersion = Bundle.main.appVersion
        prefs.lastReviewRequestedDate = .now
        try? context.save()
    }
}
