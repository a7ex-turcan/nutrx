import Foundation

extension Double {
    /// Formats a number for display: no decimals if whole, otherwise up to 2 decimal places with trailing zeros stripped.
    var displayString: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        let s = String(format: "%.2f", self)
        // Strip single trailing zero: "1.50" → "1.5", but keep "1.25" as is
        if s.hasSuffix("0") {
            return String(s.dropLast())
        }
        return s
    }
}

extension String {
    /// Parses a numeric string respecting the user's locale decimal separator (comma or dot).
    var parsedDouble: Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let value = formatter.number(from: self)?.doubleValue {
            return value
        }
        // Fallback: try with dot as decimal separator (e.g. programmatic input)
        return Double(self)
    }
}
