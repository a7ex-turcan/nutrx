import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HistoryViewModel()

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
            ForEach(viewModel.days) { day in
                NavigationLink(value: day.id) {
                    dayRow(day)
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

    private func dayRow(_ day: HistoryViewModel.DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.date.formatted(date: .long, time: .omitted))
                .font(.body.weight(.medium))

            let summary = day.nutrientTotals
                .prefix(3)
                .map { "\($0.nutrient.name): \(formatted($0.total)) \($0.nutrient.unit)" }
                .joined(separator: "  ·  ")

            let remaining = day.nutrientTotals.count - 3
            let suffix = remaining > 0 ? "  · +\(remaining) more" : ""

            Text(summary + suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
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
