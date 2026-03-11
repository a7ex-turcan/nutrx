import SwiftUI
import SwiftData

struct OnboardingFirstNutrientView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Nutrient> { !$0.isDeleted },
           sort: \Nutrient.sortOrder)
    private var nutrients: [Nutrient]

    @State private var draft = NutrientDraft()
    var onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                formSection
                if !nutrients.isEmpty {
                    addedNutrientsList
                }
                finishButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Your Nutrients")
                .font(.largeTitle.bold())

            Text("Add at least one nutrient you'd like to track.\nYou can always add more later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            NutrientFormFields(draft: draft)

            Button {
                addNutrient()
            } label: {
                Label("Add Nutrient", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .disabled(!draft.isValid)
        }
    }

    // MARK: - Added Nutrients

    private var addedNutrientsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Added (\(nutrients.count))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(nutrients) { nutrient in
                    nutrientRow(nutrient)
                }
            }
        }
    }

    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.name)
                    .font(.body.weight(.medium))

                Text("\(formatted(nutrient.dailyTarget)) \(nutrient.unit)/day  ·  step \(formatted(nutrient.step))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                modelContext.delete(nutrient)
            } label: {
                Image(systemName: "trash")
                    .font(.body)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Finish

    private var finishButton: some View {
        Button {
            onFinish()
        } label: {
            Text("Get Started")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(nutrients.isEmpty)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func addNutrient() {
        guard let stepValue = Double(draft.step),
              let targetValue = Double(draft.dailyTarget) else { return }

        let nutrient = Nutrient(
            name: draft.name.trimmingCharacters(in: .whitespaces),
            unit: draft.unit.trimmingCharacters(in: .whitespaces),
            step: stepValue,
            dailyTarget: targetValue,
            sortOrder: nutrients.count
        )
        modelContext.insert(nutrient)
        draft.reset()
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
    }
}

#Preview {
    OnboardingFirstNutrientView {}
        .modelContainer(for: [Nutrient.self, IntakeRecord.self, Exclusion.self], inMemory: true)
}
