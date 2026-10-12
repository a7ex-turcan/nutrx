import Foundation

/// User-chosen colour for a nutrient's ring, icon tile and charts.
/// Pure enum — the actual colours are resolved in `Theme`, not here.
enum NutrientTint: String, Codable, CaseIterable {
    case green, teal, blue, indigo, pink, coral, amber, brown

    /// Order used by `fallback(for:)`. Pinned on purpose — never derive it from `allCases`,
    /// or adding/reordering a case would recolour every nutrient whose tint was never chosen.
    private static let fallbackOrder: [NutrientTint] = [.green, .teal, .blue, .indigo, .pink, .coral, .amber, .brown]

    /// Stable tint for a nutrient that has never had one chosen. Derived from its id, so it's the
    /// same on every device and survives reorders. (Not `hashValue` — that's reseeded every launch.)
    static func fallback(for id: UUID) -> NutrientTint {
        let byteSum = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { $0 + Int($1) }
        }
        return fallbackOrder[byteSum % fallbackOrder.count]
    }
}
