import Foundation

/// What a supplement label says, as far as scanning could read it (nutrx Pro, docs/pro/PLAN.md phase 5). Every field
/// is optional: whatever wasn't read stays empty and the form asks for it.
struct SupplementLabel: Equatable {
    var name: String?
    /// Normalised: "IU", "mcg", "mg", "g", or the label's own word.
    var unit: String?
    var amountPerServing: Double?
    var servingsPerContainer: Int?
    /// "softgels", "capsules"… for showing "120 softgels"; not stored.
    var servingForm: String?

    var isEmpty: Bool { name == nil && unit == nil && amountPerServing == nil && servingsPerContainer == nil }
}

/// The rule-based reader: used on its own on devices without Apple Intelligence, and to fill whatever the on-device
/// model leaves out. Pure, tested against a corpus of real label texts (`LabelParserTests`).
enum LabelParser {
    static func parse(_ text: String) -> SupplementLabel {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var label = SupplementLabel()
        label.name = name(in: lines)
        let (amount, unit) = amountAndUnit(in: lines, name: label.name)
        label.amountPerServing = amount
        label.unit = unit
        let (servings, form) = servingsPerContainer(in: lines)
        label.servingsPerContainer = servings
        label.servingForm = form
        return label
    }

    // MARK: - Name

    /// Supplement names nutrx recognises in a label's text, longest first so "Vitamin D3" beats "Vitamin D".
    static let knownNames: [String] = [
        "vitamin b-complex", "vitamin b complex", "magnesium glycinate", "magnesium citrate", "creatine monohydrate",
        "omega-3", "omega 3", "fish oil", "krill oil", "vitamin b12", "vitamin b6", "vitamin d3", "vitamin d2",
        "vitamin k2", "vitamin a", "vitamin b", "vitamin c", "vitamin d", "vitamin e", "vitamin k", "multivitamin",
        "magnesium", "zinc", "iron", "calcium", "potassium", "creatine", "melatonin", "probiotics", "probiotic",
        "collagen", "ashwagandha", "turmeric", "curcumin", "coq10", "biotin", "folate", "folic acid", "iodine",
        "selenium", "electrolytes", "l-theanine", "glucosamine", "protein", "caffeine", "b12",
    ].sorted { $0.count > $1.count }

    /// Words that are on every label and never the product's name.
    private static let boilerplate = ["supplement facts", "dietary supplement", "serving size", "servings per",
                                      "amount per serving", "daily value", "other ingredients", "% dv", "suggested use",
                                      "warning", "keep out of reach", "store in", "manufactured", "distributed"]

    static func name(in lines: [String]) -> String? {
        // Above the facts panel first, where the product's name is: a known supplement, else a title line. Only then
        // a known name inside the facts, so an unknown blend listing "Melatonin 3 mg" isn't named after it.
        let factsIndex = lines.firstIndex { $0.lowercased().contains("supplement facts") } ?? lines.count
        let above = Array(lines.prefix(factsIndex))
        return knownName(in: above) ?? titleLine(in: above) ?? knownName(in: Array(lines.dropFirst(factsIndex)))
    }

    /// The first known supplement name in reading order.
    private static func knownName(in lines: [String]) -> String? {
        for line in lines {
            let lower = line.lowercased()
            // The name that comes first in the line ("Omega-3 Fish Oil" → Omega-3); the longer one on a tie
            // ("Vitamin D3" over "Vitamin D").
            let hits = knownNames.compactMap { known -> (String, String.Index)? in
                lower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: known))\\b", options: .regularExpression)
                    .map { (known, $0.lowerBound) }
            }
            if let first = hits.min(by: { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.count > $1.0.count }) {
                return displayName(first.0, as: line)
            }
        }
        return nil
    }

    /// What marks a brand line ("Nature's Best", "Acme Labs®") rather than the product's name.
    private static let brandMarks = ["'s ", "’s ", "®", "™", " labs", " naturals", " nutrition", " inc", " co.",
                                     " pharma", " organics"]

    /// The first short line that isn't boilerplate, a number or a brand.
    private static func titleLine(in lines: [String]) -> String? {
        for line in lines {
            let lower = line.lowercased() + " "
            guard (3...30).contains(line.count), !boilerplate.contains(where: lower.contains),
                  !brandMarks.contains(where: lower.contains),
                  line.rangeOfCharacter(from: .letters) != nil, line.first?.isNumber == false else { continue }
            return titleCased(line)
        }
        return nil
    }

    /// The known name as the label writes it ("VITAMIN D3" → "Vitamin D3"), keeping codes like D3, B12, Q10.
    private static func displayName(_ known: String, as line: String) -> String {
        if let range = line.range(of: known, options: [.caseInsensitive]) {
            return titleCased(String(line[range]))
        }
        return titleCased(known)
    }

    static func titleCased(_ text: String) -> String {
        text.split(separator: " ").map { word -> String in
            // Each hyphen-separated part on its own, so "Omega-3" stays "Omega-3" and "L-theanine" "L-Theanine".
            word.split(separator: "-", omittingEmptySubsequences: false).map { part -> String in
                let p = String(part)
                let letters = p.filter(\.isLetter).count
                // Codes like D3, B12, Q10, K2: short letters with digits, in capitals.
                if p.contains(where: \.isNumber) && letters <= 2 { return p.uppercased() }
                if p.count <= 3, p == p.uppercased(), p.lowercased() != "oil" { return p }
                return p.prefix(1).uppercased() + p.dropFirst().lowercased()
            }
            .joined(separator: "-")
        }
        .joined(separator: " ")
        .replacingOccurrences(of: "Coq10", with: "CoQ10")
        .replacingOccurrences(of: "COQ10", with: "CoQ10")
        .replacingOccurrences(of: "L-theanine", with: "L-Theanine")
        .replacingOccurrences(of: "Omega 3", with: "Omega-3")
    }

    // MARK: - Amount per serving

    /// A number on a label: "1,000", "1 000", "2.5", "25". It can't start right after a letter, digit, point or comma,
    /// so the 3 of "D3" or the 12 of "B12" never joins the amount after it ("Vitamin B12 500 mcg" is 500, not
    /// 12,500), and thousands are grouped with a comma or a plain space only, never across a line break.
    static let numberPattern = #"(?<![A-Za-z\d.,])(?:\d{1,3}(?:[, ]\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?)"#

    /// A number followed by a unit.
    private static let amountPattern = "(" + numberPattern + #")\s*(mcg|µg|ug|mg|g|iu)\b"#

    static func amountAndUnit(in lines: [String], name: String?) -> (Double?, String?) {
        let factsStart = lines.firstIndex { $0.lowercased().contains("supplement facts") || $0.lowercased().contains("amount per serving") } ?? 0
        let candidates = lines.enumerated().filter { index, line in
            let lower = line.lowercased()
            return index >= factsStart && !lower.contains("serving size") && !lower.contains("calories")
                && !lower.hasPrefix("total fat") && !lower.hasPrefix("total carbohydrate") && !lower.hasPrefix("sodium")
        }.map(\.element)
        let keyword = name.map { $0.lowercased().components(separatedBy: " ").prefix(2).joined(separator: " ") }

        // The line naming the product first ("Vitamin D3 … 1,000 IU"), then the first amount in the facts.
        let ordered = candidates.filter { line in keyword.map { line.lowercased().contains($0) } ?? false }
            + candidates
        for line in ordered {
            let matches = amounts(in: line)
            guard !matches.isEmpty else { continue }
            // "25 mcg (1,000 IU)": IU is what people log.
            if let iu = matches.first(where: { $0.1 == "IU" }) { return (iu.0, iu.1) }
            return (matches[0].0, matches[0].1)
        }
        return (nil, nil)
    }

    static func amounts(in line: String) -> [(Double, String)] {
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let numberRange = Range(match.range(at: 1), in: line),
                  let unitRange = Range(match.range(at: 2), in: line),
                  let value = number(String(line[numberRange])), value > 0 else { return nil }
            return (value, normalisedUnit(String(line[unitRange])))
        }
    }

    /// "1,000" / "1 000" → 1000; "2,5" (a decimal comma) → 2.5; "2.5" → 2.5.
    static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\d{1,3}([, ]\d{3})+(\.\d+)?$"#, options: .regularExpression) != nil {
            return Double(trimmed.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: ""))
        }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    static func normalisedUnit(_ unit: String) -> String {
        switch unit.lowercased() {
        case "iu": "IU"
        case "µg", "ug", "mcg": "mcg"
        case "mg": "mg"
        case "g": "g"
        default: unit
        }
    }

    // MARK: - Servings per container

    private static let formWords = #"(soft\s?gels?|capsules?|caps|veg(?:gie|etarian)?\s*caps(?:ules)?|tablets?|tabs|gummies|chewables|lozenges|scoops|sticks|packets|servings)"#

    static func servingsPerContainer(in lines: [String]) -> (Int?, String?) {
        let text = lines.joined(separator: "\n")
        if let match = firstMatch(#"servings\s*per\s*(?:container|bottle|package|pack)\s*[:\-]?\s*(?:about\s*)?(\d{1,4})"#, in: text),
           let count = Int(match[1]), count > 0 {
            return (count, form(in: lines))
        }
        // "120 softgels" (not on the serving-size line), divided by the serving size ("2 capsules").
        let countLines = lines.filter { !$0.lowercased().contains("serving size") }.joined(separator: "\n")
        guard let match = firstMatch(#"\b(\d{1,4})\s*"# + formWords + #"\b"#, in: countLines), let count = Int(match[1]),
              count > 0 else { return (nil, nil) }
        let perServing = firstMatch(#"serving\s*size\s*[:\-]?\s*(\d{1,2})"#, in: text).flatMap { Int($0[1]) } ?? 1
        return (max(1, count / max(1, perServing)), cleanForm(match[2]))
    }

    private static func form(in lines: [String]) -> String? {
        let text = lines.joined(separator: "\n")
        return firstMatch(#"\b\d{1,4}\s*"# + formWords + #"\b"#, in: text).map { cleanForm($0[1]) }
    }

    private static func cleanForm(_ word: String) -> String {
        let lower = word.lowercased().replacingOccurrences(of: " ", with: "")
        switch lower {
        case "softgel", "softgels": return "softgels"
        case "capsule", "capsules", "caps": return "capsules"
        case "tablet", "tablets", "tabs": return "tablets"
        default: return lower.contains("cap") ? "capsules" : lower
        }
    }

    /// The capture groups of the first case-insensitive match, group 0 being the whole match.
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
