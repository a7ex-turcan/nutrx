import SwiftUI

/// A goal that follows steps (nutrx Pro, #135, docs/pro/DOSE-PLANS.md §5): when it starts, 2–6 steps of a goal and a
/// length, then keep the last goal or stop. Writes the plan to the draft, and a plan that stops sets the Duration's
/// last day; the form's Save or Add applies it from today, so past days keep their goals. The steps start at the
/// nutrient's own goal: nutrx never suggests one.
struct DosePlanSheet: View {
    @Bindable var draft: NutrientDraft

    @Environment(\.dismiss) private var dismiss
    @State private var startsToday = true
    @State private var startDate = Date.now
    @State private var rows: [StepRow] = []
    @State private var end: NutrientDosePlan.End = .keep
    @State private var showRemove = false
    @FocusState private var focused: Field?

    struct StepRow: Identifiable, Equatable {
        let id = UUID()
        var target: String
        var upper: String
        var days: Int
        var inWeeks: Bool
    }

    enum Field: Hashable {
        case target(UUID), upper(UUID)
    }

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }
    private var text: DosePlanText {
        DosePlanText(goalType: draft.goalType, unit: draft.unit.trimmingCharacters(in: .whitespaces))
    }

    /// A saved plan that has started keeps its start; edits apply from today.
    private var startedOn: Date? {
        draft.savedDosePlanStart.flatMap { $0 <= today ? $0 : nil }
    }

    private var start: Date {
        startedOn ?? (startsToday ? today : max(today, calendar.startOfDay(for: startDate)))
    }

    /// What Done saves, or nil while a step's goal isn't valid.
    private var plan: NutrientDosePlan.Plan? {
        var steps: [NutrientDosePlan.Step] = []
        for row in rows {
            guard let goal = goal(of: row) else { return nil }
            steps.append(NutrientDosePlan.Step(goal: goal, days: row.days))
        }
        guard NutrientDosePlan.stepCounts.contains(steps.count) else { return nil }
        return NutrientDosePlan.Plan(start: start, steps: steps, end: end, appliesFrom: start)
    }

    /// A step's goal, checked the way the form checks one: above zero, and a range's maximum above its minimum.
    private func goal(of row: StepRow) -> NutrientGoal? {
        guard let target = row.target.parsedDouble, target > 0 else { return nil }
        guard draft.goalType == .range else { return NutrientGoal(target: target) }
        guard let upper = row.upper.parsedDouble, upper > target else { return nil }
        return NutrientGoal(target: target, upperBound: upper)
    }

    var body: some View {
        NavigationStack {
            Form {
                startSection
                stepsSection
                endSection
                Section {
                    Text(DosePlanText.noAdvice)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surfaceCard)
                if draft.dosePlan != nil {
                    Section {
                        Button("Remove Plan", role: .destructive) { showRemove = true }
                            .frame(maxWidth: .infinity)
                            // On the button, so the dialog points at it rather than at the middle of the form.
                            .confirmationDialog(DosePlanText.removeTitle, isPresented: $showRemove,
                                                titleVisibility: .visible) {
                                Button("Remove Plan", role: .destructive, action: remove)
                                Button("Keep Plan", role: .cancel) {}
                            } message: {
                                Text(removeMessage)
                            }
                    }
                    .listRowBackground(Theme.surfaceCard)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .tint(Theme.controlPrimary)
            .navigationTitle("Dose plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .fontWeight(.semibold)
                        .confirmButton(enabled: plan != nil)
                }
                // Done for the return-less amount fields, at the toolbar's root like the form's.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    @ViewBuilder
    private var startSection: some View {
        Section {
            if let startedOn {
                LabeledContent("Started", value: startedOn.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
            } else {
                Picker("Starts", selection: $startsToday) {
                    Text("Today").tag(true)
                    Text("On a date").tag(false)
                }
                .pickerStyle(.segmented)
                if !startsToday {
                    DatePicker("First day", selection: $startDate, in: today..., displayedComponents: .date)
                }
            }
        } header: {
            Text("Starting")
        } footer: {
            if startedOn != nil { Text("Changes apply from today. Past days keep their goals.") }
        }
        .listRowBackground(Theme.surfaceCard)
    }

    private var stepsSection: some View {
        Section {
            ForEach(Array(rows.indices), id: \.self) { index in
                stepRow(index)
                    .deleteDisabled(rows.count <= NutrientDosePlan.stepCounts.lowerBound)
            }
            .onDelete { offsets in
                guard rows.count - offsets.count >= NutrientDosePlan.stepCounts.lowerBound else { return }
                rows.remove(atOffsets: offsets)
            }
            if rows.count < NutrientDosePlan.stepCounts.upperBound {
                Button {
                    let last = rows.last
                    rows.append(StepRow(target: last?.target ?? draft.dailyTarget, upper: last?.upper ?? draft.upperBound,
                                        days: last?.days ?? 7, inWeeks: last?.inWeeks ?? false))
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
            }
        } header: {
            Text("Steps")
        } footer: {
            if let plan {
                Text(text.sentence(plan, today: today, courseEnd: draft.endDate))
            }
        }
        .listRowBackground(Theme.surfaceCard)
    }

    private func stepRow(_ index: Int) -> some View {
        let row = rows[index]
        let id = row.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Step \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker("Length in", selection: Binding(get: { rows[safe: index]?.inWeeks ?? false },
                                                         set: { setWeeks($0, at: index) })) {
                    Text("Days").tag(false)
                    Text("Weeks").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                amountField(binding(index, \.target), field: .target(id),
                            label: draft.goalType == .range ? "Step \(index + 1) minimum" : "Step \(index + 1) goal")
                if draft.goalType == .range {
                    Text("–").foregroundStyle(Theme.textSecondary)
                    amountField(binding(index, \.upper), field: .upper(id), label: "Step \(index + 1) maximum")
                }
                Text(draft.unit)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            .font(.system(.title3, design: .rounded, weight: .bold))
            if draft.goalType == .range, let lower = row.target.parsedDouble, let upper = row.upper.parsedDouble,
               upper <= lower {
                Text("The maximum has to be more than the minimum.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textAmberInk)
            }
            Stepper(value: lengthBinding(index), in: row.inWeeks ? 1...(NutrientDosePlan.stepDays.upperBound / 7)
                                                              : NutrientDosePlan.stepDays) {
                Text(DosePlanText.length(days: row.days, inWeeks: row.inWeeks))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private var endSection: some View {
        Section {
            ForEach([NutrientDosePlan.End.keep, .stop], id: \.self) { choice in
                Button {
                    end = choice
                } label: {
                    HStack {
                        Text(choice == .keep ? "Keep the last goal" : "Stop")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if end == choice {
                            // A real selection, so a checkmark symbol is right here (CLAUDE.md, accessibility).
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.controlPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(end == choice ? .isSelected : [])
            }
        } header: {
            Text("Then")
        } footer: {
            Text(end == .keep ? "After the last step its goal stays, with no end."
                 : "After the last step it leaves Today. It stays in My Nutrients and History.")
        }
        .listRowBackground(Theme.surfaceCard)
    }

    // MARK: - Fields

    private func amountField(_ text: Binding<String>, field: Field, label: String) -> some View {
        TextField("0", text: text)
            .keyboardType(.decimalPad)
            .focused($focused, equals: field)
            .fixedSize()
            // Room to tap while empty; once typed, the unit follows the number without a gap ("200 mg").
            .frame(minWidth: text.wrappedValue.isEmpty ? 44 : nil, alignment: .leading)
            .accessibilityLabel(draft.unit.isEmpty ? label : "\(label), \(draft.unit)")
    }

    private func binding(_ index: Int, _ keyPath: WritableKeyPath<StepRow, String>) -> Binding<String> {
        Binding(get: { rows[safe: index]?[keyPath: keyPath] ?? "" },
                set: { if rows.indices.contains(index) { rows[index][keyPath: keyPath] = $0 } })
    }

    /// The stepper's value: days, or whole weeks.
    private func lengthBinding(_ index: Int) -> Binding<Int> {
        Binding(get: {
            guard let row = rows[safe: index] else { return 1 }
            return row.inWeeks ? max(1, row.days / 7) : row.days
        }, set: { value in
            guard rows.indices.contains(index) else { return }
            rows[index].days = rows[index].inWeeks ? value * 7 : value
        })
    }

    /// Weeks round the days to whole weeks; back in days they stay as they were.
    private func setWeeks(_ inWeeks: Bool, at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].inWeeks = inWeeks
        if inWeeks { rows[index].days = max(1, Int((Double(rows[index].days) / 7).rounded())) * 7 }
    }

    // MARK: - Actions

    private func load() {
        guard rows.isEmpty else { return }
        if let saved = draft.dosePlan {
            rows = saved.steps.map { step in
                StepRow(target: NutrientDraft.editableText(step.goal.target),
                        upper: step.goal.upperBound.map { NutrientDraft.editableText($0) } ?? "",
                        // Weeks from two of them: a 7-day step was set as days more often than as a week.
                        days: step.days, inWeeks: step.days >= 14 && step.days.isMultiple(of: 7))
            }
            end = saved.end
            startsToday = saved.start <= today
            startDate = saved.start
        } else {
            // Two steps at the nutrient's own goal, for the user to change.
            rows = (0..<2).map { _ in StepRow(target: draft.dailyTarget, upper: draft.upperBound, days: 7, inWeeks: false) }
        }
    }

    private func save() {
        guard let plan else { return }
        draft.setDosePlan(plan, calendar: calendar)
        dismiss()
    }

    private func remove() {
        draft.setDosePlan(nil, calendar: calendar)
        dismiss()
    }

    /// "Past days keep the goals they had. From today Magnesium's goal is 400 mg a day." A plan keeping its last goal
    /// (or held) leaves that goal as the base; one that would stop leaves the nutrient with no end.
    private var removeMessage: String {
        let base = NutrientGoal(target: draft.dailyTarget.parsedDouble ?? 0,
                                upperBound: draft.goalType == .range ? draft.upperBound.parsedDouble : nil)
        guard let saved = draft.dosePlan else { return "" }
        let held = saved.heldFrom.map { today >= $0 } ?? false
        let settled = saved.end == .keep && today >= saved.start && saved.position(on: today, calendar: calendar) == nil
        let goal = settled || held ? saved.goal(on: today, calendar: calendar) ?? base : base
        let stops = saved.end == .stop && today <= saved.lastDay(calendar: calendar)
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        return text.removeMessage(name: name.isEmpty ? "The nutrient" : name, goalFromToday: goal, endsWithPlan: stops)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
