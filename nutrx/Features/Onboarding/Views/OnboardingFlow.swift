import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()
    @State private var step = 0

    var body: some View {
        TabView(selection: $step) {
            OnboardingPersonalInfoView(viewModel: viewModel) {
                viewModel.saveProfile(context: modelContext)
                withAnimation {
                    step = 1
                }
            }
            .tag(0)

            // Step 1 (next screen) will be added here
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: step)
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
