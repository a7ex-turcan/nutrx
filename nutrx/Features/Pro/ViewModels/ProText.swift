import Foundation

/// The words around buying and having nutrx Pro (docs/pro/design/2-paywall), kept apart from StoreKit types so
/// they can be tested: the plan rows, the primary button, the price terms under it, and the status lines.
enum ProText {
    /// "Start free week" while the yearly trial is on offer, "Subscribe", or "Buy lifetime".
    static func primaryTitle(plan: ProAccess.Plan, trialEligible: Bool) -> String {
        switch plan {
        case .yearly: trialEligible ? "Start free week" : "Subscribe"
        case .monthly: "Subscribe"
        case .lifetime: "Buy lifetime"
        }
    }

    /// The primary button's VoiceOver label: its title, or "Purchasing…" while the purchase runs and it shows only a
    /// spinner (#94).
    static func primaryAccessibilityLabel(plan: ProAccess.Plan, trialEligible: Bool, purchasing: Bool) -> String {
        purchasing ? "Purchasing…" : primaryTitle(plan: plan, trialEligible: trialEligible)
    }

    /// The price terms under the button, as App Review wants them: what's charged, how often, how to cancel.
    static func terms(plan: ProAccess.Plan, price: String, trialEligible: Bool) -> String {
        switch plan {
        case .yearly:
            trialEligible
                ? "1 week free, then \(price) a year. Cancel anytime in Settings."
                : "\(price) a year. Cancel anytime in Settings."
        case .monthly: "\(price) a month. Cancel anytime in Settings."
        case .lifetime: "One payment of \(price). No subscription."
        }
    }

    /// The pinned line above the purchase button when the plans are out of view (#189): "Yearly · $14.99 a year ·
    /// 1 week free", "Monthly · $1.99 a month", "Lifetime · $29.99 once".
    static func planSummary(plan: ProAccess.Plan, price: String, trialEligible: Bool) -> String {
        switch plan {
        case .yearly: trialEligible ? "Yearly · \(price) a year · 1 week free" : "Yearly · \(price) a year"
        case .monthly: "Monthly · \(price) a month"
        case .lifetime: "Lifetime · \(price) once"
        }
    }

    /// "Supply, label scanning, weekly recaps, Apple Health trends, doctor reports and courses are on. Nothing you
    /// already use has changed." — no serial comma, as in the design; "Supply is on." for one.
    static func welcome(_ features: [ProFeature]) -> String {
        let names = features.map(\.welcomeName)
        guard let last = names.last else { return "Nothing you already use has changed." }
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + last : last
        let verb = names.count == 1 ? "is" : "are"
        return list.prefix(1).uppercased() + list.dropFirst() + " \(verb) on. Nothing you already use has changed."
    }

    /// Settings' card line for a free user, from what's actually shipped: one feature reads as itself ("Know when a
    /// bottle runs out"), two or three as a list ("Supply, label scan and recaps"), and only four or more get "and
    /// more", so it never hints at a feature that isn't there.
    static func tagline(_ features: [ProFeature]) -> String {
        let names = features.map(\.shortName)
        let text: String
        switch names.count {
        case 0: return "More around your tracking"
        case 1: return features[0].subtitle
        case 2, 3: text = names.dropLast().joined(separator: ", ") + " and " + names.last!
        default: text = names.prefix(3).joined(separator: ", ") + " and more"
        }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// The paywall's line under the features on a device without Apple Intelligence, naming only the listed
    /// features it improves ("Apple Intelligence makes label scanning and recaps richer. …"); nil when none is listed.
    static func appleIntelligenceNote(_ features: [ProFeature], device: String) -> String? {
        let names = features.compactMap(\.appleIntelligenceName)
        guard let last = names.last else { return nil }
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + last : last
        return "Apple Intelligence makes \(list) richer. Every Pro feature still works on this \(device)."
    }

    /// The note under a paywall row that Apple Intelligence improves, on a device without it: "Basic text reading
    /// on this iPhone" (scan), "Simpler wording on this iPhone" (recap).
    static func appleIntelligenceRowNote(_ feature: ProFeature, reading: ScanText.Reading, device: String) -> String? {
        switch feature {
        case .scan: ScanText.paywallNote(reading, device: device)
        case .recap: reading.mentionsAppleIntelligence ? "Simpler wording on this \(device)" : nil
        case .supply, .health, .report, .courses: nil
        }
    }

    static func planTitle(_ plan: ProAccess.Plan) -> String {
        switch plan {
        case .yearly: "Yearly"
        case .monthly: "Monthly"
        case .lifetime: "Lifetime"
        }
    }

    /// "$1.25 a month, billed yearly", "Billed monthly", "Pay once, keep Pro forever".
    static func planSubtitle(_ plan: ProAccess.Plan, monthlyEquivalent: String?) -> String {
        switch plan {
        case .yearly: monthlyEquivalent.map { "\($0) a month, billed yearly" } ?? "Billed yearly"
        case .monthly: "Billed monthly"
        case .lifetime: "Pay once, keep Pro forever"
        }
    }

    /// The yearly price spread over twelve months, in the product's own currency format ("$1.25").
    static func monthlyEquivalent(ofYearly price: Decimal, format: Decimal.FormatStyle.Currency) -> String {
        var perMonth = price / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perMonth, 2, .plain)
        return rounded.formatted(format)
    }

    /// Today's plan chip (#101): "PRO" on Pro, "Free" otherwise.
    static func planChipTitle(isPro: Bool) -> String { isPro ? "PRO" : "Free" }

    static func planChipAccessibilityLabel(isPro: Bool) -> String {
        isPro ? "nutrx Pro, active" : "Free plan. See what nutrx Pro adds"
    }

    /// Settings' card: "Yearly · renews 14 Oct 2027", "Yearly · free until 21 Oct", "Monthly · ends 3 Nov 2026",
    /// "Lifetime".
    static func shortStatus(_ entitlement: ProAccess.Entitlement, locale: Locale = .current) -> String {
        status(entitlement, dateStyle: Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    /// The Pro screen: "Yearly plan · renews 14 October 2027", "Lifetime · yours for good".
    static func longStatus(_ entitlement: ProAccess.Entitlement, locale: Locale = .current) -> String {
        if entitlement.plan == .lifetime { return "Lifetime · yours for good" }
        return status(entitlement, dateStyle: Date.FormatStyle(date: .long, time: .omitted).locale(locale), suffix: " plan")
    }

    private static func status(_ entitlement: ProAccess.Entitlement, dateStyle: Date.FormatStyle,
                               suffix: String = "") -> String {
        let name = planTitle(entitlement.plan) + suffix
        guard entitlement.plan != .lifetime, let end = entitlement.expirationDate else { return name }
        let date = end.formatted(dateStyle)
        if entitlement.isTrial && entitlement.willAutoRenew { return "\(name) · free until \(date)" }
        return entitlement.willAutoRenew ? "\(name) · renews \(date)" : "\(name) · ends \(date)"
    }
}
