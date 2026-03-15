import SwiftUI
import SwiftData

struct HistoryDayView: View {
    @Environment(\.modelContext) private var modelContext
    let day: HistoryViewModel.DaySummary
    let viewModel: HistoryViewModel

    @State private var selectedNutrient: Nutrient?
    @State private var intakeEntries: [HistoryViewModel.IntakeEntry] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(day.nutrientTotals, id: \.nutrient.persistentModelID) { entry in
                    NutrientRowView(
                        nutrient: entry.nutrient,
                        currentIntake: entry.total
                    )
                    .onTapGesture {
                        intakeEntries = viewModel.intakeRecords(for: entry.nutrient, on: day.date, context: modelContext)
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
            intakeDetailSheet(for: nutrient)
        }
    }

    @ViewBuilder
    private func intakeDetailSheet(for nutrient: Nutrient) -> some View {
        let entries = intakeEntries
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)

                            Spacer()

                            let sign: String = entry.amount >= 0 ? "+" : ""
                            Text("\(sign)\(formatted(entry.amount)) \(nutrient.unit)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(entry.amount >= 0 ? Color.primary : Color.red)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        if entry.id != entries.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(nutrient.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
