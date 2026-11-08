import Foundation
import SwiftData

/// How you feel's questions (#133, docs/pro/HOW-YOU-FEEL.md §1, §6): the presets and the user's own, in the user's
/// order. The only writer of `FeelingQuestion`s. Each change saves.
enum FeelingQuestions {
    /// The user's own questions at a time.
    static let ownLimit = 5
    static let titleLimit = 40

    /// Why a title for the user's own question can't be used.
    enum TitleProblem: Equatable {
        case empty
        /// An active question already reads this, ignoring case.
        case duplicate
    }

    /// Every question, removed ones too, in order.
    static func all(in context: ModelContext) -> [FeelingQuestion] {
        let descriptor = FetchDescriptor<FeelingQuestion>(sortBy: [SortDescriptor(\.sortOrder),
                                                                   SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The questions on the card, in order.
    static func active(in context: ModelContext) -> [FeelingQuestion] {
        all(in: context).filter { !$0.isRemoved }
    }

    /// The presets that aren't on the card, in the presets' order.
    static func presetsToAdd(besides active: [FeelingQuestion]) -> [FeelingPreset] {
        let on = Set(active.compactMap(\.preset))
        return FeelingPreset.allCases.filter { !on.contains($0) }
    }

    /// The first time How you feel is turned on, Energy, Mood and Sleep. Later it keeps whatever the user chose,
    /// even none.
    static func setUpIfNeeded(in context: ModelContext) {
        guard all(in: context).isEmpty else { return }
        for preset in FeelingPreset.starting {
            context.insert(FeelingQuestion(title: preset.title, kind: preset.kind, presetRaw: preset.rawValue,
                                           sortOrder: nextSortOrder(in: context)))
        }
        try? context.save()
    }

    /// Puts a preset on the card, at the end. One that was removed comes back with its answers.
    @discardableResult
    static func add(_ preset: FeelingPreset, in context: ModelContext) -> FeelingQuestion {
        if let existing = all(in: context).first(where: { $0.preset == preset }) {
            if existing.isRemoved {
                existing.isRemoved = false
                existing.sortOrder = nextSortOrder(in: context)
                try? context.save()
            }
            return existing
        }
        let question = FeelingQuestion(title: preset.title, kind: preset.kind, presetRaw: preset.rawValue,
                                       sortOrder: nextSortOrder(in: context))
        context.insert(question)
        try? context.save()
        return question
    }

    /// Takes a question off the card. Its answers stay for History and the patterns.
    static func remove(_ question: FeelingQuestion, in context: ModelContext) {
        question.isRemoved = true
        try? context.save()
    }

    /// The user's own questions among the card's.
    static func ownCount(of active: [FeelingQuestion]) -> Int {
        active.filter { $0.preset == nil }.count
    }

    static func canAddOwn(in context: ModelContext) -> Bool {
        ownCount(of: active(in: context)) < ownLimit
    }

    /// A title as it's kept: trimmed, at most `titleLimit` characters.
    static func cleanTitle(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(titleLimit))
    }

    /// What's wrong with a title for the user's own question, if anything. `editing` is the question being renamed.
    static func problem(with text: String, editing: FeelingQuestion? = nil, in context: ModelContext) -> TitleProblem? {
        let title = cleanTitle(text)
        guard !title.isEmpty else { return .empty }
        let taken = active(in: context).contains {
            $0 !== editing && $0.displayTitle.compare(title, options: .caseInsensitive) == .orderedSame
        }
        return taken ? .duplicate : nil
    }

    /// Adds the user's own question at the end, or brings back a removed one with the same title and kind (and its
    /// answers). Nil when the title can't be used or there are already `ownLimit`.
    @discardableResult
    static func addOwn(title text: String, kind: FeelingKind, in context: ModelContext) -> FeelingQuestion? {
        guard problem(with: text, in: context) == nil, canAddOwn(in: context) else { return nil }
        let title = cleanTitle(text)
        if let removed = all(in: context).first(where: {
            $0.isRemoved && $0.preset == nil && $0.kind == kind
                && $0.title.compare(title, options: .caseInsensitive) == .orderedSame
        }) {
            removed.isRemoved = false
            removed.title = title
            removed.sortOrder = nextSortOrder(in: context)
            try? context.save()
            return removed
        }
        let question = FeelingQuestion(title: title, kind: kind, sortOrder: nextSortOrder(in: context))
        context.insert(question)
        try? context.save()
        return question
    }

    /// Renames the user's own question. False for a preset, or a title that can't be used.
    @discardableResult
    static func rename(_ question: FeelingQuestion, to text: String, in context: ModelContext) -> Bool {
        guard question.preset == nil, problem(with: text, editing: question, in: context) == nil else { return false }
        question.title = cleanTitle(text)
        try? context.save()
        return true
    }

    /// Only the user's own, and only before it has answers: a scale and yes / no don't mix.
    static func canChangeKind(of question: FeelingQuestion) -> Bool {
        question.preset == nil && (question.answers ?? []).isEmpty
    }

    @discardableResult
    static func setKind(_ kind: FeelingKind, of question: FeelingQuestion, in context: ModelContext) -> Bool {
        guard canChangeKind(of: question) else { return false }
        question.kind = kind
        try? context.save()
        return true
    }

    /// Reorders the card's questions; removed ones keep their places after them.
    static func move(fromOffsets source: IndexSet, toOffset destination: Int, in context: ModelContext) {
        // The list's move, without SwiftUI: the moved rows go in before what was at `destination`.
        let current = active(in: context)
        let moved = source.sorted().map { current[$0] }
        var questions = current.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        questions.insert(contentsOf: moved, at: destination - source.filter { $0 < destination }.count)
        for (index, question) in questions.enumerated() {
            question.sortOrder = index
        }
        for (offset, question) in all(in: context).filter(\.isRemoved).enumerated() {
            question.sortOrder = questions.count + offset
        }
        try? context.save()
    }

    /// Two devices that turned on the same preset before syncing made two questions for it. Keeps the oldest,
    /// moves the other's answers to it, and deletes the copy (a day both answered keeps both answers; the newest
    /// is read, §6). On if either was. Run at launch and whenever the app becomes active, like
    /// `StackLogging.repairDuplicateIDs`.
    @discardableResult
    static func mergeDuplicatePresets(in context: ModelContext) -> Bool {
        var kept: [FeelingPreset: FeelingQuestion] = [:]
        var changed = false
        let questions = ((try? context.fetch(FetchDescriptor<FeelingQuestion>(sortBy: [SortDescriptor(\.createdAt)])))
            ?? [])
        for question in questions {
            guard let preset = question.preset else { continue }
            guard let keeper = kept[preset] else {
                kept[preset] = question
                continue
            }
            for answer in question.answers ?? [] {
                answer.question = keeper
            }
            if !question.isRemoved { keeper.isRemoved = false }
            context.delete(question)
            changed = true
        }
        if changed {
            try? context.save()
        }
        return changed
    }

    private static func nextSortOrder(in context: ModelContext) -> Int {
        (all(in: context).map(\.sortOrder).max() ?? -1) + 1
    }
}
