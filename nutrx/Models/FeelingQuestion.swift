import Foundation
import SwiftData

/// How you feel (#133, docs/pro/HOW-YOU-FEEL.md §1): one question of the daily check-in, a preset or the user's own.
/// Removing one only sets `isRemoved`, so History and the patterns keep its answers.
@Model
final class FeelingQuestion {
    var id: UUID = UUID()
    /// The user's own wording. A preset's is `FeelingPreset.title`, so this only matters for the user's own.
    var title: String = ""
    var kindRaw: String = FeelingKind.scale.rawValue
    /// The preset this is (`FeelingPreset`'s raw value), nil for the user's own. One question per preset: turning a
    /// preset back on reuses it.
    var presetRaw: String? = nil
    var sortOrder: Int = 0
    var isRemoved: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \FeelingAnswer.question)
    var answers: [FeelingAnswer]? = []

    var kind: FeelingKind {
        get { FeelingKind(rawValue: kindRaw) ?? .scale }
        set { kindRaw = newValue.rawValue }
    }

    init(title: String, kind: FeelingKind, presetRaw: String? = nil, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.kindRaw = kind.rawValue
        self.presetRaw = presetRaw
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

/// How a question is answered: 1–5, or yes / no (stored as 1 / 0).
enum FeelingKind: String, CaseIterable {
    case scale
    case yesNo
}
