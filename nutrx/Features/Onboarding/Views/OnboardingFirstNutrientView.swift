import SwiftUI
import SwiftData

struct OnboardingFirstNutrientView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Nutrient> { !$0.isDeleted },
           sort: \Nutrient.sortOrder)
    private var nutrients: [Nutrient]
    @Query(filter: #Predicate<NutrientGroup> { $0.isSystem }) private var systemGroups: [NutrientGroup]

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

            Text("Add at least one nutrient you'd like to track.\nYou can add more and configure reminders later.")
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

                Text("\(nutrient.dailyTarget.displayString) \(nutrient.unit)/day  ·  step \(nutrient.step.displayString)")
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
        guard let stepValue = draft.step.parsedDouble,
              let targetValue = draft.dailyTarget.parsedDouble else { return }

        let nutrient = Nutrient(
            name: draft.name.trimmingCharacters(in: .whitespaces),
            unit: draft.unit.trimmingCharacters(in: .whitespaces),
            step: stepValue,
            dailyTarget: targetValue,
            sortOrder: nutrients.count
        )
        let notes = draft.notes.trimmingCharacters(in: .whitespaces)
        nutrient.notes = notes.isEmpty ? nil : notes

        if let general = systemGroups.first {
            nutrient.group = general
            nutrient.groupSortOrder = ((general.nutrients ?? []).map(\.groupSortOrder).max() ?? -1) + 1
        }

        modelContext.insert(nutrient)
        draft.reset()
    }

}

#Preview {
    OnboardingFirstNutrientView {}
        .modelContainer(for: [Nutrient.self, IntakeRecord.self, Exclusion.self], inMemory: true)
}
