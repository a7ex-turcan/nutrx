import SwiftUI
import SwiftData

/// "How was today?" on Today (#133, docs/pro/HOW-YOU-FEEL.md §2): How you feel's questions from the Ask from time
/// until the day ends. Answers save as they're tapped. Once every question has one, the card folds to a line
/// ("Checked in · Energy 4 · Mood 3") with Edit, and ✕ hides it until tomorrow.
struct FeelingTodayCard: View {
    let questions: [FeelingQuestion]
    let values: [PersistentIdentifier: Int]
    let onAnswer: (FeelingQuestion, Int?) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Edit opens a finished card again; it stays open until Today is next shown.
    @State private var isEditing = false

    private var isFolded: Bool {
        !isEditing && FeelingAnswers.isComplete(questions, values: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isFolded ? 4 : 14) {
            HStack(alignment: .center) {
                Text(FeelingText.cardTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if isFolded {
                    headerButton("Edit", hint: "Shows the questions again") { isEditing = true }
                } else if isEditing {
                    // Folds it again; while answering for the first time it folds on the last answer.
                    headerButton("Done", hint: "Folds the card") { isEditing = false }
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide until tomorrow")
            }
            .padding(.trailing, -10)  // the ✕'s touch area reaches the card's padding

            if isFolded {
                Text(FeelingText.checkedIn(questions, values: values))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FeelingQuestionRows(questions: questions, values: values) { question, value in
                    withAnimation(.unlessReduceMotion(reduceMotion)) { onAnswer(question, value) }
                }
            }
        }
        .padding(.leading, Theme.Spacing.cardPadding + 2)
        .padding(.trailing, Theme.Spacing.cardPadding)
        .padding(.top, 4)
        .padding(.bottom, Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func headerButton(_ title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.unlessReduceMotion(reduceMotion)) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                .padding(.horizontal, 8)
                .frame(minHeight: Theme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }
}

/// Energy, Mood, Sleep and Headache, with `answered` of them answered.
private struct FeelingTodayCardPreview: View {
    var answered = 0
    @State private var questions: [FeelingQuestion] = []

    var body: some View {
        let values = Dictionary(uniqueKeysWithValues: questions.prefix(answered).enumerated().map { index, question in
            (question.persistentModelID, question.kind == .yesNo ? 0 : 4 - index)
        })
        ScrollView {
            FeelingTodayCard(questions: questions, values: values, onAnswer: { _, _ in }, onDismiss: {})
                .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.surfaceGround)
        .task {
            let context = previewContainer.mainContext
            FeelingQuestions.setUpIfNeeded(in: context)
            FeelingQuestions.add(.headache, in: context)
            questions = FeelingQuestions.active(in: context)
        }
    }
}

#Preview("Unanswered") {
    FeelingTodayCardPreview()
        .modelContainer(previewContainer)
}

#Preview("Checked in") {
    FeelingTodayCardPreview(answered: 4)
        .modelContainer(previewContainer)
}

#Preview("Accessibility 3") {
    FeelingTodayCardPreview(answered: 2)
        .environment(\.dynamicTypeSize, .accessibility3)
        .modelContainer(previewContainer)
}
