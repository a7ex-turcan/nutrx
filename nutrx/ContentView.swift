import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var hasStartedWaiting = false
    @State private var hasFinishedWaiting = false
    @AppStorage("wasSyncRestored") private var wasSyncRestored = false

    private var isOnboardingComplete: Bool {
        profiles.first?.onboardingCompleted == true
    }

    var body: some View {
        if isOnboardingComplete {
            MainTabView()
                .onAppear {
                    // Only mark as sync-restored on a genuinely new device:
                    // the profile arrived from iCloud during the loading wait.
                    // Once the flag is consumed, clear it so it never retriggers.
                    if hasStartedWaiting && !hasFinishedWaiting {
                        wasSyncRestored = true
                    }
                }
        } else if !hasFinishedWaiting {
            SyncLoadingView()
                .task {
                    hasStartedWaiting = true
                    try? await Task.sleep(for: .seconds(3))
                    hasFinishedWaiting = true
                }
        } else {
            OnboardingFlow()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
