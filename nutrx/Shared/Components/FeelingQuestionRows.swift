import SwiftUI
import SwiftData

/// How you feel's questions with answers to tap (#133, docs/pro/HOW-YOU-FEEL.md §2): five buttons 1–5 with the end
/// words under them, or Yes and No. A tap saves; tapping the answer again clears it. Today's card and History's edit
/// sheet both use it.
struct FeelingQuestionRows: View {
    let questions: [FeelingQuestion]
    let values: [PersistentIdentifier: Int]
    let onAnswer: (FeelingQuestion, Int?) -> Void

    var body: some View {
        // One layout for every row, so the answers line up: beside the names when every name fits beside its answers
        // unbroken (a wide card), else each name above its answers (a phone, mostly). A name never wraps beside them.
        ViewThatFits(in: .horizontal) {
            rows(answersBeside: true)
            rows(answersBeside: false)
        }
    }

    private func rows(answersBeside: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(questions, id: \.persistentModelID) { question in
                FeelingQuestionRow(question: question, value: values[question.persistentModelID],
                                   answersBeside: answersBeside) { value in
                    onAnswer(question, value)
                }
            }
        }
    }
}

private struct FeelingQuestionRow: View {
    let question: FeelingQuestion
    let value: Int?
    let answersBeside: Bool
    let onAnswer: (Int?) -> Void

    var body: some View {
        if answersBeside {
            HStack(alignment: .center, spacing: 12) {
                label
                    .fixedSize()
                Spacer(minLength: 0)
                answers
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                label
                answers
            }
        }
    }

    private var label: some View {
        Label {
            Text(question.displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: question.symbolName)
                .foregroundStyle(Theme.SettingsTile.pink)
        }
        .labelStyle(.titleAndIcon)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var answers: some View {
        switch question.kind {
        case .scale: scale
        case .yesNo: yesNo
        }
    }

    /// 1 to 5, the end words under the first and last; one adjustable element for VoiceOver ("Energy, 4 of 5").
    private var scale: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { number in
                    Button { onAnswer(value == number ? nil : number) } label: {
                        Text("\(number)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(value == number ? Theme.controlOnPrimary : Theme.textPrimary)
                            .frame(minWidth: 38, minHeight: 38)
                            .background(value == number ? Theme.controlPrimary : Theme.surfaceChip, in: Circle())
                            // 44 pt to tap, around a 38 pt circle.
                            .frame(minWidth: Theme.minTouchTarget, minHeight: Theme.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(question.ends.low)
                Spacer()
                Text(question.ends.high)
            }
            .padding(.horizontal, 3)
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(question.displayTitle)
        .accessibilityValue(FeelingText.scaleValue(value))
        .accessibilityHint("1 is \(question.ends.low.lowercased()), 5 is \(question.ends.high.lowercased())")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onAnswer(min(5, (value ?? 0) + 1))
            case .decrement: onAnswer(value.map { max(1, $0 - 1) } ?? 1)
            @unknown default: break
            }
        }
    }

    private var yesNo: some View {
        HStack(spacing: 8) {
            choice("Yes", value: 1)
            choice("No", value: 0)
        }
        .padding(.horizontal, 3)  // in line with the scale's circles, inset in their 44 pt
        .fixedSize()
    }

    private func choice(_ title: String, value choice: Int) -> some View {
        let selected = value == choice
        return Button { onAnswer(selected ? nil : choice) } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Theme.controlOnPrimary : Theme.textPrimary)
                .padding(.horizontal, 18)
                .frame(minHeight: Theme.minTouchTarget)
                .background(selected ? Theme.controlPrimary : Theme.surfaceChip, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(question.displayTitle), \(title.lowercased())")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
