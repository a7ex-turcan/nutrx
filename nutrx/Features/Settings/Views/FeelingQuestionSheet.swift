import SwiftUI
import SwiftData

/// A How you feel question of the user's own (#133, docs/pro/HOW-YOU-FEEL.md §1): its name and how it's answered,
/// 1 to 5 or yes or no. Editing one can't change the kind once it has answers, and can remove it.
struct FeelingQuestionSheet: View {
    /// Nil for a new question.
    let question: FeelingQuestion?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var kind: FeelingKind
    @FocusState private var titleFocused: Bool

    init(question: FeelingQuestion?) {
        self.question = question
        _title = State(initialValue: question?.title ?? "")
        _kind = State(initialValue: question?.kind ?? .scale)
    }

    private var problem: FeelingQuestions.TitleProblem? {
        FeelingQuestions.problem(with: title, editing: question, in: modelContext)
    }

    private var canChangeKind: Bool {
        question.map(FeelingQuestions.canChangeKind(of:)) ?? true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Question", text: $title, prompt: Text("Bloating, Skin, Motivation…"))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityLabel("Question")
                        .onChange(of: title) { _, new in
                            if new.count > FeelingQuestions.titleLimit {
                                title = String(new.prefix(FeelingQuestions.titleLimit))
                            }
                        }
                } header: {
                    Text("Question")
                } footer: {
                    if let note = FeelingText.titleProblem(problem) {
                        Text(note)
                            .foregroundStyle(Theme.textAmberInk)
                    }
                }
                .listRowBackground(Theme.surfaceCard)

                Section {
                    Picker("Answer", selection: $kind) {
                        ForEach(FeelingKind.allCases, id: \.self) { kind in
                            Text(FeelingText.kindName(kind)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!canChangeKind)
                } header: {
                    Text("Answer")
                } footer: {
                    Text(canChangeKind ? FeelingText.kindExplanation(kind) : FeelingText.kindLocked(kind))
                }
                .listRowBackground(Theme.surfaceCard)

                if let question {
                    Section {
                        Button("Remove Question", role: .destructive) {
                            FeelingQuestions.remove(question, in: modelContext)
                            dismiss()
                        }
                    } footer: {
                        Text("Its answers stay in History.")
                    }
                    .listRowBackground(Theme.surfaceCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .tint(Theme.controlPrimary)
            .navigationTitle(question == nil ? "Your own question" : "Edit question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(question == nil ? "Add" : "Save", action: save)
                        .fontWeight(.semibold)
                        .confirmButton(enabled: problem == nil)
                }
            }
            .onAppear { if question == nil { titleFocused = true } }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard problem == nil else { return }
        if let question {
            FeelingQuestions.rename(question, to: title, in: modelContext)
            FeelingQuestions.setKind(kind, of: question, in: modelContext)
        } else {
            FeelingQuestions.addOwn(title: title, kind: kind, in: modelContext)
        }
        dismiss()
    }
}

#Preview("New") {
    FeelingQuestionSheet(question: nil)
        .modelContainer(previewContainer)
}

/// An answered question of your own: the kind is locked, and Remove Question shows.
#Preview("Edit, answered") {
    let container = previewContainer
    let question = FeelingQuestion(title: "Skin", kind: .yesNo, sortOrder: 0)
    container.mainContext.insert(question)
    container.mainContext.insert(FeelingAnswer(question: question, day: Calendar.current.startOfDay(for: .now),
                                               value: 1))
    return FeelingQuestionSheet(question: question)
        .modelContainer(container)
}
