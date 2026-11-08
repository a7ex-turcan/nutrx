import Foundation

/// How you feel's preset questions (#133, docs/pro/HOW-YOU-FEEL.md §1). Pure; the raw value is what
/// `FeelingQuestion.presetRaw` stores, so never rename one.
enum FeelingPreset: String, CaseIterable {
    case energy, mood, sleep, focus, stress, digestion, headache, aches

    /// On when How you feel is first turned on.
    static let starting: [FeelingPreset] = [.energy, .mood, .sleep]

    var title: String {
        switch self {
        case .energy: "Energy"
        case .mood: "Mood"
        case .sleep: "Sleep last night"
        case .focus: "Focus"
        case .stress: "Stress"
        case .digestion: "Digestion"
        case .headache: "Headache"
        case .aches: "Aches or pains"
        }
    }

    var kind: FeelingKind {
        switch self {
        case .headache, .aches: .yesNo
        default: .scale
        }
    }

    /// The words under 1 and 5 of the user's own scales.
    static let ownEnds = (low: "Low", high: "High")

    /// The words under 1 and 5.
    var ends: (low: String, high: String) {
        switch self {
        case .mood, .sleep, .digestion: ("Poor", "Great")
        default: ("Low", "High")
        }
    }

    var symbolName: String {
        switch self {
        case .energy: "bolt"
        case .mood: "face.smiling"
        case .sleep: "moon.zzz"
        case .focus: "scope"
        case .stress: "wind"
        case .digestion: "fork.knife"
        case .headache: "brain.head.profile"
        case .aches: "bandage"
        }
    }

    /// Answered in the evening, Sleep describes the night before, so the patterns pair it with the day before (§1).
    var isAboutNightBefore: Bool { self == .sleep }
}

extension FeelingQuestion {
    var preset: FeelingPreset? { presetRaw.flatMap(FeelingPreset.init(rawValue:)) }

    /// What the question reads: a preset's title, or the user's own.
    var displayTitle: String { preset?.title ?? title }

    var symbolName: String { preset?.symbolName ?? "text.bubble" }

    /// The words under 1 and 5; the user's own scales read Low – High.
    var ends: (low: String, high: String) { preset?.ends ?? FeelingPreset.ownEnds }
}
