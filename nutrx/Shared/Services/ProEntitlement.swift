import Foundation
import StoreKit

/// nutrx Pro's products and the rule for what unlocks it — pure, plus one StoreKit read, for places that can't use
/// `ProAccess`: the notification handler on a background launch, and the widget extension (its "Running low" line).
/// Nothing here is stored: it's read from StoreKit on the device each time.
nonisolated enum ProEntitlement {
    /// The App Store Connect products (subscription group "nutrx Pro", plus the lifetime non-consumable).
    enum ProductID {
        static let monthly = "nutrx.pro.monthly"
        static let yearly = "nutrx.pro.yearly"
        static let lifetime = "nutrx.pro.lifetime"
        static let all = [yearly, monthly, lifetime]
        static let subscriptionGroupID = "22477669"
    }

    enum Plan: Equatable {
        case monthly
        case yearly
        case lifetime

        init?(productID: String) {
            switch productID {
            case ProductID.monthly: self = .monthly
            case ProductID.yearly: self = .yearly
            case ProductID.lifetime: self = .lifetime
            default: return nil
            }
        }
    }

    /// What gives Pro right now.
    struct Entitlement: Equatable {
        let plan: Plan
        /// When a subscription period ends; nil for lifetime.
        let expirationDate: Date?
        /// Bought by a family member and shared through Family Sharing.
        let isFamilyShared: Bool
        /// In the yearly plan's free week.
        var isTrial: Bool = false
        /// A subscription that renews at `expirationDate` (false once cancelled; false for lifetime).
        var willAutoRenew: Bool = false
    }

    /// One verified transaction, reduced to what decides the entitlement (so the rule is testable without StoreKit).
    struct Candidate: Equatable {
        let productID: String
        let revocationDate: Date?
        let expirationDate: Date?
        let isUpgraded: Bool
        let isFamilyShared: Bool
        var isTrial: Bool = false
    }

    /// The rule, kept pure: revoked (refunded) and upgraded-away transactions don't count, nor an expired
    /// subscription; lifetime beats any subscription, yearly beats monthly; own purchases beat family-shared ones.
    static func entitlement(from candidates: [Candidate], now: Date = .now) -> Entitlement? {
        let valid = candidates.filter { candidate in
            candidate.revocationDate == nil && !candidate.isUpgraded
                && (candidate.expirationDate.map { $0 > now } ?? true)
                && Plan(productID: candidate.productID) != nil
        }
        func rank(_ candidate: Candidate) -> Int {
            let plan: Int
            switch Plan(productID: candidate.productID)! {
            case .lifetime: plan = 3
            case .yearly: plan = 2
            case .monthly: plan = 1
            }
            return plan * 2 + (candidate.isFamilyShared ? 0 : 1)
        }
        guard let best = valid.max(by: { rank($0) < rank($1) }), let plan = Plan(productID: best.productID)
        else { return nil }
        return Entitlement(plan: plan, expirationDate: plan == .lifetime ? nil : best.expirationDate,
                           isFamilyShared: best.isFamilyShared, isTrial: plan != .lifetime && best.isTrial)
    }

    /// The current entitlement straight from StoreKit (verified transactions only), without renewal info — for
    /// places that only need "is this person Pro": the widget, and notification actions on a background launch.
    #if DEBUG
    /// The App Group default that makes Debug builds of the widget extension Pro (`current()`).
    static let debugWidgetsProKey = "nutrx.debug.widgetsPro"
    #endif

    static func current(now: Date = .now) async -> Entitlement? {
        #if DEBUG
        // The widget extension never sees Xcode's local StoreKit, so simulator checks of the Pro widgets and controls
        // turn this on (docs/pro/WIDGETS.md §6). Extensions only: the app reads its own StoreKit test purchases.
        if Bundle.main.bundlePath.hasSuffix(".appex"),
           UserDefaults(suiteName: ModelContainerFactory.appGroupID)?.bool(forKey: debugWidgetsProKey) == true {
            return Entitlement(plan: .lifetime, expirationDate: nil, isFamilyShared: false)
        }
        #endif
        var candidates: [Candidate] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            candidates.append(Candidate(transaction))
        }
        return entitlement(from: candidates, now: now)
    }
}

extension ProEntitlement.Candidate {
    init(_ transaction: Transaction) {
        self.init(productID: transaction.productID,
                  revocationDate: transaction.revocationDate,
                  expirationDate: transaction.expirationDate,
                  isUpgraded: transaction.isUpgraded,
                  isFamilyShared: transaction.ownershipType == .familyShared,
                  isTrial: transaction.offer?.type == .introductory)
    }
}
