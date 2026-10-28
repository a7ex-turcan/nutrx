import Foundation
import FoundationModels

/// A recap's words that `RecapPhrasing` can reword and check: the week's (`RecapText`) and the month's
/// (`MonthlyRecapText`, #136).
protocol RecapWording {
    var period: RecapPhrasing.Period { get }
    /// The template summary.
    var summary: String { get }
    /// Every number the words may use.
    var factNumbers: Set<Int> { get }
    /// The steadiest nutrient's name, which a rewording has to keep when the template has it.
    var steadiestName: String? { get }
    /// The period's key in the cache: "week-<epoch>", "month-2026-10", "year-2026".
    var cacheKey: String { get }
}

/// The recap's summary in friendlier words (nutrx Pro, docs/pro/PLAN.md phase 6): with Apple Intelligence, the
/// on-device model rewords the template summary, prompted with those facts only. Its text is checked — every number
/// in it must be one of the recap's, it may not advise, and it has to name the steadiest nutrient — or the template
/// stays. A reworded summary is kept per period on this device (UserDefaults; it's derived from the log, never
/// synced), so the recap doesn't change each time it's opened, and is redone only when the facts change.
enum RecapPhrasing {
    enum Period: String {
        case week, month, year
    }

    protocol Model {
        func reword(_ facts: String, period: Period) async throws -> String
    }

    /// The summary to show: the cached rewording for these facts, a fresh one, or the template.
    static func summary(for text: some RecapWording, model: Model? = defaultModel,
                        store: UserDefaults = .standard) async -> String {
        let template = text.summary
        let key = text.cacheKey
        if let cached = store.dictionary(forKey: cacheStoreKey)?[key] as? [String],
           cached.count == 2, cached[0] == template {
            return cached[1]
        }
        guard let model else { return template }
        // A rejected rewording or a model error keeps the template for these facts too, so the words don't change
        // between opens if a later attempt would pass.
        var summary = template
        if let reworded = try? await model.reword(template, period: text.period), isAcceptable(reworded, for: text) {
            summary = reworded
        }
        var cache = store.dictionary(forKey: cacheStoreKey) ?? [:]
        cache[key] = [template, summary]
        store.set(pruned(cache), forKey: cacheStoreKey)
        return summary
    }

    /// How many of each kind the cache keeps: the last weeks, months and years.
    static let kept: [Period: Int] = [.week: 12, .month: 12, .year: 3]

    /// The newest of each kind, kept separately, so months and years never push the weeks out. Keys from before
    /// #136 (epoch seconds, no kind) count as weeks.
    static func pruned(_ cache: [String: Any]) -> [String: Any] {
        var kept: [String: Any] = [:]
        let byKind = Dictionary(grouping: cache.keys) { key -> Period in
            Period(rawValue: String(key.prefix { $0 != "-" })) ?? .week
        }
        for (kind, keys) in byKind {
            // Same-kind keys sort by date: equal-length epochs, "2026-10", "2026".
            for key in keys.sorted().suffix(Self.kept[kind] ?? 12) { kept[key] = cache[key] }
        }
        return kept
    }

    static var defaultModel: Model? {
        LabelExtractor.isModelAvailable ? FoundationRecapModel() : nil
    }

    static let cacheStoreKey = "nutrx.recapSummaries"

    // MARK: - Checking

    /// Words that turn a description into advice.
    static let adviceWords = ["should", "try ", "trying", "consider", "recommend", "aim ", "aim for", "make sure",
                              "don't forget", "remember to", "need to", "increase", "decrease", "reduce", "boost",
                              "improve", "keep up", "goal for next", "next week", "next month", "next year"]

    static func isAcceptable(_ reworded: String, for text: some RecapWording) -> Bool {
        let trimmed = reworded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (20...420).contains(trimmed.count) else { return false }
        let lower = trimmed.lowercased()
        guard !adviceWords.contains(where: lower.contains) else { return false }
        // The steadiest nutrient, when the template names it, has to stay.
        if let name = text.steadiestName?.lowercased(), text.summary.lowercased().contains(name),
           !lower.contains(name) { return false }
        let numbers = numbers(in: trimmed)
        // Spelled-out numbers are checked too ("seven of seven days").
        let words = lower.split(whereSeparator: { !$0.isLetter }).compactMap { numberWords[String($0)] }
        return Set(numbers + words).isSubset(of: text.factNumbers)
    }

    /// The numbers in a text, a grouped one ("3,960", "3 960") read as one, not as 3 and 960.
    static func numbers(in text: String) -> [Int] {
        let grouped = /\d{1,3}(?:[,\u{00A0}\u{202F}]\d{3})+|\d+/
        return text.matches(of: grouped).compactMap { Int(String($0.output).filter(\.isNumber)) }
    }

    static let numberWords: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20, "once": 1, "twice": 2,
    ]
}

// MARK: - The on-device model

@Generable
struct GeneratedRecapSummary {
    @Guide(description: "Three or four short sentences describing the user's tracking over the period, using only the facts given.")
    var summary: String
}

struct FoundationRecapModel: RecapPhrasing.Model {
    func reword(_ facts: String, period: RecapPhrasing.Period) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite a short summary of someone's supplement and nutrient tracking over the past \(period.rawValue), \
            speaking to them as "you". Keep every name and number exactly as given and add no new facts. Describe \
            only: never give advice, never suggest amounts, changes or goals, and never judge. Plain, warm, three or \
            four sentences.
            """)
        let response = try await session.respond(to: "Facts:\n\(facts)", generating: GeneratedRecapSummary.self)
        return response.content.summary
    }
}
