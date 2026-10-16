import SwiftUI

/// How long a nutrient is taken (nutrx Pro, #99): ongoing, for a number of days from today, or until a date. Writes
/// the last day to the draft; the form's Save or Add applies it.
struct DurationSheet: View {
    @Bindable var draft: NutrientDraft

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .ongoing
    @State private var days = 5
    @State private var untilDate = Date.now

    private enum Mode: Hashable, CaseIterable {
        case ongoing, days, date

        var title: String {
            switch self {
            case .ongoing: "Ongoing"
            case .days: "For days"
            case .date: "Until a date"
            }
        }
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var lastDay: Date? {
        switch mode {
        case .ongoing: nil
        case .days: NutrientCourse.lastDay(days: days, from: today)
        case .date: Calendar.current.startOfDay(for: untilDate)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Duration", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                switch mode {
                case .ongoing:
                    Section {
                        Text("Shown on Today every day, with no end.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.surfaceCard)
                case .days:
                    Section {
                        Stepper(value: $days, in: 1...365) {
                            Text(days == 1 ? "1 day" : "\(days) days")
                                .monospacedDigit()
                        }
                    } footer: {
                        if let lastDay { Text("Counting today. " + CourseText().untilSentence(lastDay)) }
                    }
                    .listRowBackground(Theme.surfaceCard)
                case .date:
                    Section {
                        DatePicker("Last day", selection: $untilDate, in: today..., displayedComponents: .date)
                    } footer: {
                        if let lastDay { Text(CourseText().untilSentence(lastDay)) }
                    }
                    .listRowBackground(Theme.surfaceCard)
                }
            }
            .contentMargins(.top, 8, for: .scrollContent)  // the picker right under the bar
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .tint(Theme.controlPrimary)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        draft.endDate = lastDay
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // An existing course opens on its last day; one that's already over opens as ongoing.
                if let endDate = draft.endDate, !NutrientCourse.hasEnded(endDate, by: .now) {
                    mode = .date
                    untilDate = endDate
                    days = NutrientCourse.dayCount(from: today, to: endDate)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
