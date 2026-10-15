import Foundation
import FoundationModels

/// Reads a supplement label's recognised text into a `SupplementLabel` (nutrx Pro, docs/pro/PLAN.md phase 5).
///
/// With Apple Intelligence, the on-device model reads it (guided generation into `GeneratedLabel`), prompted with
/// the recognised text only; without it, `LabelParser` does. Either way the result is checked against the text —
/// a number the model reports has to appear on the label — and anything left empty is filled from the parser.
/// Nothing leaves the device.
enum LabelExtractor {
    /// The on-device model, behind a protocol so tests can stand in for it.
    protocol Model {
        func read(_ text: String) async throws -> SupplementLabel
    }

    struct Result: Equatable {
        let label: SupplementLabel
        /// Read by the on-device model (false: the rule-based parser alone).
        let usedModel: Bool
    }

    /// Apple Intelligence is on and the model is ready on this device.
    static var isModelAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Whether Apple Intelligence could be turned on here (the device supports it), for the "turned off" note.
    static var isModelTurnedOff: Bool {
        if case .unavailable(.appleIntelligenceNotEnabled) = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func extract(from text: String, model: Model? = defaultModel) async -> Result {
        let parsed = LabelParser.parse(text)
        guard let model else { return Result(label: parsed, usedModel: false) }
        guard let read = try? await model.read(text) else { return Result(label: parsed, usedModel: false) }
        return Result(label: merge(checked(read, against: text), parsed), usedModel: true)
    }

    /// The model when it's available, else nil (the parser alone).
    static var defaultModel: Model? {
        isModelAvailable ? FoundationLabelModel() : nil
    }

    // MARK: - Checking the model

    /// Drops what the model can't back up: numbers that aren't on the label, out-of-range values, empty or long
    /// names, units that aren't units.
    static func checked(_ label: SupplementLabel, against text: String) -> SupplementLabel {
        var result = SupplementLabel()
        if let name = label.name?.trimmingCharacters(in: .whitespacesAndNewlines), (2...40).contains(name.count) {
            result.name = LabelParser.titleCased(name)
        }
        if let unit = label.unit.map(LabelParser.normalisedUnit), ["IU", "mcg", "mg", "g"].contains(unit) {
            result.unit = unit
        }
        let numbers = numbersOnLabel(text)
        if let amount = label.amountPerServing, amount > 0, amount < 1_000_000, numbers.contains(amount) {
            result.amountPerServing = amount
        }
        if let servings = label.servingsPerContainer, (1...2000).contains(servings), numbers.contains(Double(servings)) {
            result.servingsPerContainer = servings
        }
        result.servingForm = label.servingForm
        return result
    }

    /// Every number written on the label ("1,000" counts as 1000), so the model's numbers can be checked.
    static func numbersOnLabel(_ text: String) -> Set<Double> {
        guard let regex = try? NSRegularExpression(pattern: #"\d{1,3}(?:[,\s]\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?"#) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).flatMap { LabelParser.number(String(text[$0])) }
        })
    }

    /// The model's fields first, the parser's where the model left a gap.
    static func merge(_ primary: SupplementLabel, _ fallback: SupplementLabel) -> SupplementLabel {
        SupplementLabel(name: primary.name ?? fallback.name,
                        unit: primary.unit ?? fallback.unit,
                        amountPerServing: primary.amountPerServing ?? fallback.amountPerServing,
                        servingsPerContainer: primary.servingsPerContainer ?? fallback.servingsPerContainer,
                        servingForm: primary.servingForm ?? fallback.servingForm)
    }
}

// MARK: - The on-device model

/// What the model fills in. Optional fields: it leaves out what the label doesn't say rather than guessing.
@Generable
struct GeneratedLabel {
    @Guide(description: "The supplement's name as printed, e.g. \"Vitamin D3\" or \"Magnesium Glycinate\". Not the brand.")
    var name: String?
    @Guide(description: "The unit of the main ingredient's amount per serving: IU, mcg, mg or g. Prefer IU when both IU and mcg are given.")
    var unit: String?
    @Guide(description: "The main ingredient's amount in one serving, as a number, e.g. 1000 for \"1,000 IU\".")
    var amountPerServing: Double?
    @Guide(description: "Servings per container, as a number, e.g. 120.")
    var servingsPerContainer: Int?
    @Guide(description: "What one serving is, plural: softgels, capsules, tablets, gummies, scoops…")
    var servingForm: String?
}

struct FoundationLabelModel: LabelExtractor.Model {
    func read(_ text: String) async throws -> SupplementLabel {
        let session = LanguageModelSession(instructions: """
            You read supplement labels. From the label text you're given, extract only what it states. \
            If something isn't on the label, leave it out. Never estimate or recommend amounts.
            """)
        let response = try await session.respond(to: "Label text:\n\(text)", generating: GeneratedLabel.self)
        let generated = response.content
        return SupplementLabel(name: generated.name, unit: generated.unit,
                               amountPerServing: generated.amountPerServing,
                               servingsPerContainer: generated.servingsPerContainer,
                               servingForm: generated.servingForm)
    }
}
