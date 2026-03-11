import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]

    private var isOnboardingComplete: Bool {
        profiles.first?.onboardingCompleted == true
    }

    var body: some View {
        if isOnboardingComplete {
            Text("Main App")
        } else {
            OnboardingFlow()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
