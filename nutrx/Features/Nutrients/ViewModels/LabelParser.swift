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
    /// Every ingredient row on the facts panel with an amount ("Vitamin B6 2.5 mg", "Magnesium 200 mg"), for
    /// "Also on this label". Nutrition rows (calories, fat, sodium…) aren't ingredients.
    var ingredients: [LabelIngredient] = []

    var isEmpty: Bool { name == nil && unit == nil && amountPerServing == nil && servingsPerContainer == nil }
}

/// One ingredient row of a facts panel: "Magnesium 200 mg".
struct LabelIngredient: Equatable, Hashable {
    let name: String
    let amount: Double
    let unit: String
}

/// The rule-based reader: used on its own on devices without Apple Intelligence, and to fill whatever the on-device
/// model leaves out. Pure, tested against a corpus of real label texts (`LabelParserTests`).
enum LabelParser {
    static func parse(_ text: String) -> SupplementLabel {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var label = SupplementLabel()
        label.ingredients = ingredients(in: factsLines(lines))
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
        // Above the facts panel first, where the product's name is: a known supplement, else a title line. A photo of
        // just the facts panel has none, so then the main ingredient row names it (Magnesium 200 mg over Vitamin B6
        // 2.5 mg), and only then a known name anywhere in the facts.
        let factsIndex = factsHeaderIndex(lines) ?? lines.count
        return nameAboveFacts(lines)
            ?? mainIngredient(ingredients(in: factsLines(lines)))?.name
            ?? knownName(in: Array(lines.dropFirst(factsIndex)))
    }

    /// Where the facts panel starts: "Supplement Facts" (text recognition can drop the space: "SupplementFacts"), or
    /// failing that "Amount Per Serving".
    static func factsHeaderIndex(_ lines: [String]) -> Int? {
        func squeezed(_ line: String) -> String { line.lowercased().replacingOccurrences(of: " ", with: "") }
        return lines.firstIndex { squeezed($0).contains("supplementfacts") }
            ?? lines.firstIndex { squeezed($0).contains("amountperserving") }
    }

    /// The product's name from above the facts panel, if the label shows one there. Sentences ("Avoid taking with
    /// other foods containing protein…") aren't names, so only short lines count.
    static func nameAboveFacts(_ lines: [String]) -> String? {
        let factsIndex = factsHeaderIndex(lines) ?? lines.count
        let above = lines.prefix(factsIndex).filter { $0.count <= 32 }
        return knownName(in: above) ?? titleLine(in: above)
    }

    // MARK: - Ingredient rows

    /// Nutrition rows a facts panel can start with; not what the product is, unless they're all there is (a protein
    /// powder).
    private static let nutritionRows = ["calories", "total fat", "saturated fat", "trans fat", "cholesterol", "sodium",
                                        "total carbohydrate", "carbohydrate", "dietary fiber", "total sugars",
                                        "sugars", "added sugars", "protein"]

    /// The facts panel's ingredient rows with an amount, in order, named the way the form would ("Total Omega-3s"
    /// → Omega-3, "Hydrolyzed Bovine Collagen Peptides" → Collagen, "Benfotiamine" as printed).
    static func ingredients(in factsLines: [String]) -> [LabelIngredient] {
        rows(in: factsLines).filter { !$0.isNutrition }.map(\.ingredient)
    }

    /// The main ingredient when the product's name isn't printed above the facts: omega-3 over the fish oil it comes
    /// from, else the largest amount by weight (Magnesium 200 mg over Vitamin B6 2.5 mg, Collagen 3 g over Vitamin C
    /// 30 mg). Nutrition rows only when there's nothing else (Protein 25 g on a protein powder).
    static func mainIngredient(_ ingredients: [LabelIngredient], nutrition: [LabelIngredient] = []) -> LabelIngredient? {
        let pool = ingredients.isEmpty ? nutrition : ingredients
        if let omega = pool.first(where: { $0.name == "Omega-3" }) { return omega }
        let byWeight = pool.compactMap { item in milligrams(item).map { (item, $0) } }
        if let heaviest = byWeight.enumerated().max(by: { a, b in
            a.element.1 != b.element.1 ? a.element.1 < b.element.1 : a.offset > b.offset
        }) {
            return heaviest.element.0
        }
        return pool.first
    }

    private static func milligrams(_ item: LabelIngredient) -> Double? {
        switch item.unit {
        case "g": item.amount * 1000
        case "mg": item.amount
        case "mcg": item.amount / 1000
        default: nil
        }
    }

    private struct Row {
        let ingredient: LabelIngredient
        let isNutrition: Bool
    }

    /// Lines of the form "<name> <amount> <unit> …": the name is what comes before the first amount, without
    /// brackets and marks; footnotes ("Less than 5 mg of cholesterol", "Daily Value…") aren't rows.
    private static func rows(in lines: [String]) -> [Row] {
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: [.caseInsensitive]) else { return [] }
        return lines.compactMap { line in
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range, in: line), let amount = preferredAmount(in: line) else { return nil }
            var label = String(line[..<range.lowerBound])
            label = label.replacingOccurrences(of: #"\([^)]*\)?"#, with: " ", options: .regularExpression)
            label = label.components(separatedBy: CharacterSet.letters.union(.decimalDigits)
                .union(CharacterSet(charactersIn: " -")).inverted).joined()
                .trimmingCharacters(in: .whitespaces)
            let lower = label.lowercased()
            guard label.filter(\.isLetter).count >= 3,
                  !["daily value", "percent", "less than", "serving", "calorie diet"].contains(where: lower.contains)
            else { return nil }
            let name = knownName(in: [label]) ?? titleCased(label)
            return Row(ingredient: LabelIngredient(name: name, amount: amount.0, unit: amount.1),
                       isNutrition: nutritionRows.contains { lower.hasPrefix($0) })
        }
    }

    /// The first known supplement name in reading order.
    private static func knownName(in lines: [String]) -> String? {
        for line in lines {
            // "Omega-3s" is omega-3 ("Total Omega-3s 1,280 mg").
            let lower = line.lowercased().replacingOccurrences(of: "omega-3s", with: "omega-3 ")
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

    /// What marks a brand line ("Acme Labs®") rather than the product's name: such a line is never the name.
    private static let brandMarks = ["®", "™", " labs", " naturals", " nutrition", " inc", " co.", " pharma", " organics"]
    /// A weaker mark: "Nature's Best" is a brand, but "Women's Multi" is a product, so it's only passed over while
    /// another line follows.
    private static let possessiveMarks = ["'s ", "’s "]

    /// The first short line that isn't boilerplate, a number or a brand ("Acme Labs®" never is). A possessive line
    /// is passed over while another follows: "Nature's Best" above "Calm Night" gives Calm Night, but "Women's Multi"
    /// on its own is the name.
    private static func titleLine(in lines: [String]) -> String? {
        let candidates = lines.filter { line in
            let lower = line.lowercased() + " "
            return (3...30).contains(line.count) && !boilerplate.contains(where: lower.contains)
                && !brandMarks.contains(where: lower.contains)
                && line.rangeOfCharacter(from: .letters) != nil && line.first?.isNumber == false
        }
        let named = candidates.first { !possessiveMarks.contains(where: ($0.lowercased() + " ").contains) }
            ?? candidates.first
        return named.map(titleCased)
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

    /// A number on a label: "1,000", "1 000", "2.5", "25". It can't start right after a letter, digit, point, comma
    /// or hyphen, so the 3 of "D3", "Omega-3" or "D-3" and the 12 of "B12" never join the amount after it ("Vitamin
    /// B12 500 mcg" is 500, not 12,500). Thousands are grouped with a comma or a plain space only, never across a line
    /// break, and a group is exactly three digits ("1 0000" isn't 10,000).
    static let numberPattern = #"(?<![A-Za-z\d.,\-])(?:\d{1,3}(?:[, ]\d{3})+(?!\d)(?:\.\d+)?|\d+(?:[.,]\d+)?)"#

    /// A number followed by a unit.
    private static let amountPattern = "(" + numberPattern + #")\s*(mcg|µg|ug|mg|g|iu)\b"#

    static func amountAndUnit(in lines: [String], name: String?) -> (Double?, String?) {
        let candidates = factsLines(lines)
        // The line naming the product first, then the first amount in the facts.
        if let named = namedAmount(in: candidates, name: name) { return (named.0, named.1) }
        for line in candidates {
            if let amount = preferredAmount(in: line) { return (amount.0, amount.1) }
        }
        return (nil, nil)
    }

    /// The amount on the facts line for the ingredient the product is named after, if there is one: a line with the
    /// name ("Vitamin D3 … 1,000 IU"), else one starting with its main word ("Magnesium 200 mg" for Magnesium
    /// Glycinate, whose "(as magnesium glycinate)" line has no amount). Not other ingredients ("Vitamin B6 2.5 mg"),
    /// which come first on many labels.
    static func namedAmount(in lines: [String], name: String?) -> (Double, String)? {
        guard let name = name?.lowercased() else { return nil }
        let words = name.components(separatedBy: " ").filter { !$0.isEmpty }
        let keyword = words.prefix(2).joined(separator: " ")
        // "Vitamin D3" can't fall back to "vitamin": that's every vitamin on the panel.
        let head = words.first == "vitamin" ? keyword : (words.first ?? keyword)
        let withName = lines.filter { $0.lowercased().contains(keyword) }
        let startingWithHead = lines.filter { $0.lowercased().hasPrefix(head) }
        for line in withName + startingWithHead {
            if let amount = preferredAmount(in: line) { return amount }
        }
        return nil
    }

    /// The facts panel's lines with an amount worth reading: from "Supplement Facts" (or "Amount per serving") on,
    /// without serving size, calories, fat, carbohydrate or sodium.
    static func factsLines(_ lines: [String]) -> [String] {
        let factsStart = factsHeaderIndex(lines) ?? 0
        return lines.enumerated().filter { index, line in
            let lower = line.lowercased()
            return index >= factsStart && !lower.contains("serving size") && !lower.contains("calories")
                && !lower.hasPrefix("total fat") && !lower.hasPrefix("total carbohydrate") && !lower.hasPrefix("sodium")
        }.map(\.element)
    }

    /// A line's amount, IU first ("25 mcg (1,000 IU)": IU is what people log).
    private static func preferredAmount(in line: String) -> (Double, String)? {
        let matches = amounts(in: line)
        return matches.first { $0.1 == "IU" } ?? matches.first
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
