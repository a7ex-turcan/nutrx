import SwiftUI
import SwiftData

/// "How you felt" on a History day (#133, docs/pro/HOW-YOU-FEEL.md §2): the day's How you feel answers, removed
/// questions' included, or "No check-in". The last week's can be changed with Edit while How you feel is on; older
/// days are read-only.
struct FeelingDayCard: View {
    let date: Date
    let questions: [FeelingQuestion]
    /// How you feel is on: off, the card only shows a day's answers.
    var canEdit = true
    let onEdit: () -> Void

    var body: some View {
        let values = FeelingAnswers.values(for: questions, on: date)
        let answered = questions.filter { values[$0.persistentModelID] != nil }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(FeelingText.historyTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if canEdit, FeelingAnswers.isEditable(date), questions.contains(where: { !$0.isRemoved }) {
                    Button(action: onEdit) {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.controlPrimary)
                            .padding(.horizontal, 8)
                            .frame(minHeight: Theme.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Changes this day's answers")
                }
            }
            if answered.isEmpty {
                Text(FeelingText.noCheckIn)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(answered, id: \.persistentModelID) { question in
                    let value = values[question.persistentModelID] ?? 0
                    HStack {
                        Label {
                            Text(question.displayTitle)
                        } icon: {
                            Image(systemName: question.symbolName)
                                .foregroundStyle(Theme.SettingsTile.pink)
                                .accessibilityHidden(true)
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        Text(question.kind == .scale ? FeelingText.scaleValue(value)
                                                     : FeelingText.answer(value, kind: .yesNo))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// History's Edit for How you feel: the day's questions to answer again, as on Today's card.
struct FeelingDaySheet: View {
    let date: Date
    let questions: [FeelingQuestion]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                FeelingQuestionRows(questions: questions,
                                    values: FeelingAnswers.values(for: questions, on: date)) { question, value in
                    FeelingAnswers.set(value, for: question, on: date, in: modelContext)
                    Haptics.adjusted()
                }
                .padding(Theme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(Theme.Spacing.screenMargin)
            }
            .background(Theme.surfaceGround)
            .navigationTitle(FeelingText.historyTitle)
            .navigationSubtitle(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Yesterday with three answers (Edit shows), and a day with none.
private struct FeelingDayCardPreview: View {
    @State private var questions: [FeelingQuestion] = []
    private let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.cardGap) {
                FeelingDayCard(date: yesterday, questions: questions, onEdit: {})
                FeelingDayCard(date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
                               questions: questions, onEdit: {})
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
        .task {
            let context = previewContainer.mainContext
            FeelingQuestions.setUpIfNeeded(in: context)
            let headache = FeelingQuestions.add(.headache, in: context)
            let all = FeelingQuestions.active(in: context)
            for (question, value) in zip(all, [4, 2, 5]) {
                FeelingAnswers.set(value, for: question, on: yesterday, in: context)
            }
            if let headache { FeelingAnswers.set(1, for: headache, on: yesterday, in: context) }
            questions = all
        }
    }
}

#Preview {
    FeelingDayCardPreview()
        .modelContainer(previewContainer)
}
