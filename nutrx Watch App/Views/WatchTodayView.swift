import SwiftUI
import SwiftData
import WatchKit

/// The Watch's only screen (DESIGN.md §5.11): "Today" + "3/6", then a row per nutrient on `Watch/Cell`.
/// Tapping + logs one step and shows `WatchLogConfirmationView` for a moment.
struct WatchTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = WatchTodayViewModel()

    /// How long the confirmation stays up; a tap dismisses it sooner.
    private static let confirmationDuration = Duration.seconds(1.5)

    var body: some View {
        // The stack's bar gives the clock a scroll-edge fade over the rows.
        NavigationStack {
            WatchTodayList(sections: viewModel.sections,
                           hasNutrients: viewModel.hasNutrients,
                           showsGroupHeaders: viewModel.hasCustomGroups,
                           metCount: viewModel.metCount,
                           totalCount: viewModel.totalCount,
                           onIncrement: log)
        }
        .accessibilityHidden(viewModel.confirmation != nil)
        .overlay {
            if let confirmation = viewModel.confirmation {
                WatchLogConfirmationView(confirmation: confirmation)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.confirmation = nil }
                    .transition(.opacity)
                    .task(id: confirmation.id) {
                        do { try await Task.sleep(for: Self.confirmationDuration) } catch { return }
                        if viewModel.confirmation?.id == confirmation.id {
                            viewModel.confirmation = nil
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.confirmation?.id)
        .onAppear {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            // Picks up a new day, and whatever synced from the iPhone while the app was away.
            if phase == .active { viewModel.refresh(context: modelContext) }
        }
    }

    private func log(_ nutrient: Nutrient) {
        viewModel.increment(nutrient, context: modelContext)
        guard let confirmation = viewModel.confirmation else { return }
        WKInterfaceDevice.current().play(confirmation.metGoal ? .success : .click)

        let announcement = WidgetSummary.loggedAnnouncement(confirmation.amount, unit: nutrient.unit, name: nutrient.name,
                                                            progress: confirmation.item.progress.progressText)
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// The list itself, separate from the data so previews can show it.
struct WatchTodayList: View {
    let sections: [WatchTodayViewModel.GroupSection]
    /// False before the first sync brings any nutrients over; true when they're all excluded today.
    let hasNutrients: Bool
    let showsGroupHeaders: Bool
    let metCount: Int
    let totalCount: Int
    let onIncrement: (Nutrient) -> Void

    var body: some View {
        List {
            if sections.isEmpty {
                Section {
                    Text(hasNutrients ? "Nothing to track today" : "Add a nutrient on your iPhone")
                        .font(.footnote)
                        .foregroundStyle(Theme.onForestSecondary)
                        .listRowBackground(Color.clear)
                } header: {
                    header
                }
            }

            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                Section {
                    ForEach(section.items) { item in
                        WatchNutrientRowView(item: item) { onIncrement(item.nutrient) }
                            .listRowBackground(RoundedRectangle(cornerRadius: Theme.Radius.watchCell).fill(Theme.watchCell))
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    }
                } header: {
                    // "Today" + "3/6" heads the first section rather than taking a row of its own:
                    // list rows have a tall minimum height on watchOS.
                    VStack(alignment: .leading, spacing: 10) {
                        if index == 0 { header }
                        if showsGroupHeaders { Text(section.name) }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.greenSoft)
            Spacer()
            if totalCount > 0 {
                Text(WidgetSummary.score(met: metCount, total: totalCount))
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(Theme.onForestSecondary)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(totalCount > 0 ? "Today, \(metCount) of \(totalCount) \(GoalProgress.goals(totalCount)) met" : "Today")
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Today") {
    let sections = [WatchTodayViewModel.GroupSection(id: WatchPreviewData.items[0].id, name: "General",
                                                     items: WatchPreviewData.items)]
    WatchTodayList(sections: sections, hasNutrients: true, showsGroupHeaders: false,
                   metCount: WatchPreviewData.items.filter { $0.progress.countsAsMet }.count,
                   totalCount: WatchPreviewData.items.count, onIncrement: { _ in })
}
#endif
