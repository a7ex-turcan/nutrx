import Foundation
import FoundationModels

/// The recap's summary in friendlier words (nutrx Pro, docs/pro/PLAN.md phase 6): with Apple Intelligence, the
/// on-device model rewords `RecapText.summary`, prompted with those facts only. Its text is checked — every number
/// in it must be one of the recap's, it may not advise, and it has to name the steadiest nutrient — or the template
/// stays. A reworded summary is kept per week on this device (UserDefaults; it's derived from the log, never synced),
/// so the recap doesn't change each time it's opened, and is redone only when the facts change.
enum RecapPhrasing {
    protocol Model {
        func reword(_ facts: String) async throws -> String
    }

    /// The summary to show: the cached rewording for these facts, a fresh one, or the template.
    static func summary(for text: RecapText, model: Model? = defaultModel,
                        store: UserDefaults = .standard) async -> String {
        let template = text.summary
        let key = cacheKey(text.recap.weekStart)
        if let cached = store.dictionary(forKey: cacheStoreKey)?[key] as? [String],
           cached.count == 2, cached[0] == template {
            return cached[1]
        }
        guard let model, let reworded = try? await model.reword(template),
              isAcceptable(reworded, for: text) else { return template }
        var cache = store.dictionary(forKey: cacheStoreKey) ?? [:]
        cache[key] = [template, reworded]
        // Only the last few weeks.
        if cache.count > 12, let oldest = cache.keys.sorted().first { cache[oldest] = nil }
        store.set(cache, forKey: cacheStoreKey)
        return reworded
    }

    static var defaultModel: Model? {
        LabelExtractor.isModelAvailable ? FoundationRecapModel() : nil
    }

    static let cacheStoreKey = "nutrx.recapSummaries"

    private static func cacheKey(_ weekStart: Date) -> String {
        String(Int(weekStart.timeIntervalSince1970))
    }

    // MARK: - Checking

    /// Words that turn a description into advice.
    static let adviceWords = ["should", "try ", "trying", "consider", "recommend", "aim ", "aim for", "make sure",
                              "don't forget", "remember to", "need to", "increase", "decrease", "reduce", "boost",
                              "improve", "keep up", "goal for next", "next week"]

    static func isAcceptable(_ reworded: String, for text: RecapText) -> Bool {
        let trimmed = reworded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (20...420).contains(trimmed.count) else { return false }
        let lower = trimmed.lowercased()
        guard !adviceWords.contains(where: lower.contains) else { return false }
        // The steadiest nutrient, when the template names it, has to stay.
        if let name = text.recap.steadiest?.name.lowercased(), text.summary.lowercased().contains(name),
           !lower.contains(name) { return false }
        let numbers = trimmed.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return Set(numbers).isSubset(of: text.factNumbers)
    }
}

// MARK: - The on-device model

@Generable
struct GeneratedRecapSummary {
    @Guide(description: "Three or four short sentences describing the user's week, using only the facts given.")
    var summary: String
}

struct FoundationRecapModel: RecapPhrasing.Model {
    func reword(_ facts: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite a short weekly summary of someone's supplement and nutrient tracking, speaking to them as \
            "you". Keep every name and number exactly as given and add no new facts. Describe only: never give \
            advice, never suggest amounts, changes or goals, and never judge. Plain, warm, three or four sentences.
            """)
        let response = try await session.respond(to: "Facts:\n\(facts)", generating: GeneratedRecapSummary.self)
        return response.content.summary
    }
}
