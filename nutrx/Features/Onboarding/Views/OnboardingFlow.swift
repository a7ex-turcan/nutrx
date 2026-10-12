import SwiftUI
import SwiftData

/// Welcome → first nutrient (DESIGN.md §5.8). Finishing either way sets `UserProfile.onboardingCompleted`, which
/// `ContentView` watches to switch to the tabs.
struct OnboardingFlow: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .welcome:
                OnboardingWelcomeView {
                    go(to: .firstNutrient)
                }
                .transition(transition(edge: .leading))
            case .firstNutrient:
                OnboardingFirstNutrientView(viewModel: viewModel) {
                    go(to: .welcome)
                }
                .transition(transition(edge: .trailing))
            }
        }
    }

    private func go(to step: OnboardingViewModel.Step) {
        withAnimation(.easeInOut(duration: 0.3)) { viewModel.step = step }
    }

    private func transition(edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge)
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(for: [UserProfile.self, Nutrient.self, NutrientGroup.self, IntakeRecord.self], inMemory: true)
}
