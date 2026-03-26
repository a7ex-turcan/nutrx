import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = HistoryViewModel()
    @State private var streak: StreakResult?

    private var preferences: UserPreferences? { allPreferences.first }

    var body: some View {
        Group {
            if viewModel.days.isEmpty {
                emptyState
            } else {
                dayList
            }
        }
        .onAppear {
            viewModel.refresh(context: modelContext)
            streak = StreakService.compute(context: modelContext)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "clock")
        } description: {
            Text("Your past daily intake logs will appear here.")
        }
    }

    private var dayList: some View {
        List {
            if let streak, preferences?.streaksEnabled != false,
               (streak.current > 0 || streak.best > 0) {
                Section {
                    HStack {
                        Label {
                            Text("Current streak")
                        } icon: {
                            Text("🔥")
                        }
                        Spacer()
                        Text("\(streak.current) days")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label {
                            Text("Best streak")
                        } icon: {
                            Text("🏆")
                        }
                        Spacer()
                        Text("\(streak.best) days")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(viewModel.monthSections) { section in
                Section(section.label) {
                    ForEach(section.days) { day in
                        NavigationLink(value: day.id) {
                            dayRow(day)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Date.self) { dayID in
            if let day = viewModel.days.first(where: { $0.id == dayID }) {
                HistoryDayView(day: day, viewModel: viewModel)
            }
        }
    }

    private func isStreakDay(_ day: HistoryViewModel.DaySummary) -> Bool {
        guard !day.nutrientTotals.isEmpty else { return false }
        return day.nutrientTotals.allSatisfy { $0.total >= $0.nutrient.dailyTarget }
    }

    private func dayRow(_ day: HistoryViewModel.DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(day.date.formatted(date: .long, time: .omitted))
                    .font(.body.weight(.medium))

                if preferences?.streaksEnabled != false && isStreakDay(day) {
                    Text("🔥")
                        .font(.caption)
                }
            }

            let summary = day.nutrientTotals
                .prefix(3)
                .map { "\($0.nutrient.name): \($0.total.displayString) \($0.nutrient.unit)" }
                .joined(separator: "  ·  ")

            let remaining = day.nutrientTotals.count - 3
            let suffix = remaining > 0 ? "  · +\(remaining) more" : ""

            Text(summary + suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

}

#Preview {
    NavigationStack {
        HistoryListView()
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
