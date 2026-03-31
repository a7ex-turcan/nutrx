import SwiftUI
import SwiftData

struct HistoryDayView: View {
    @Environment(\.modelContext) private var modelContext
    let day: HistoryViewModel.DaySummary
    let viewModel: HistoryViewModel

    @State private var selectedNutrient: Nutrient?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(day.nutrientTotals, id: \.nutrient.persistentModelID) { entry in
                    NutrientRowView(
                        nutrient: entry.nutrient,
                        currentIntake: entry.total
                    )
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        selectedNutrient = entry.nutrient
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(day.date.formatted(date: .long, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedNutrient) { nutrient in
            IntakeDetailSheet(
                nutrient: nutrient,
                day: day.date,
                viewModel: viewModel
            )
        }
    }
}

private struct IntakeDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    let nutrient: Nutrient
    let day: Date
    let viewModel: HistoryViewModel

    @State private var entries: [HistoryViewModel.IntakeEntry] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    Text("No records")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    let sign: String = entry.amount >= 0 ? "+" : ""
                                    Text("\(sign)\(entry.amount.displayString) \(nutrient.unit)")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(entry.amount >= 0 ? Color.primary : Color.red)
                                }

                                if let note = entry.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            if index < entries.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(nutrient.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            entries = viewModel.intakeRecords(for: nutrient, on: day, context: modelContext)
        }
    }

}
