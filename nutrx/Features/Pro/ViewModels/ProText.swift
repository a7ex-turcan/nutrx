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

    /// "Supply, label scanning, weekly recaps, Apple Health trends and doctor reports are on. Nothing you
    /// already use has changed." — no serial comma, as in the design; "Supply is on." for one.
    static func welcome(_ features: [ProFeature]) -> String {
        let names: [String] = features.map { feature in
            switch feature {
            case .supply: "supply"
            case .scan: "label scanning"
            case .recap: "weekly recaps"
            case .health: "Apple Health trends"
            case .report: "doctor reports"
            }
        }
        guard let last = names.last else { return "Nothing you already use has changed." }
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + last : last
        let verb = names.count == 1 ? "is" : "are"
        return list.prefix(1).uppercased() + list.dropFirst() + " \(verb) on. Nothing you already use has changed."
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
