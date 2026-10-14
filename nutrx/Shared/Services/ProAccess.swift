import Foundation
import Observation
import StoreKit

/// Whether this person has nutrx Pro, from StoreKit 2 on the device (docs/pro/PLAN.md, phase 3). Reads
/// `Transaction.currentEntitlements` at launch, follows `Transaction.updates` (renewals, refunds, Ask to Buy, a
/// purchase on another device), buys and restores. The entitlement is never stored — not in SwiftData, not in
/// iCloud, not in UserDefaults: it's derived from StoreKit every launch, and no receipt leaves the device.
@MainActor
@Observable
final class ProAccess {
    /// The App Store Connect products (subscription group "nutrx Pro", plus the lifetime non-consumable).
    nonisolated enum ProductID {
        static let monthly = "nutrx.pro.monthly"
        static let yearly = "nutrx.pro.yearly"
        static let lifetime = "nutrx.pro.lifetime"
        static let all = [yearly, monthly, lifetime]
        static let subscriptionGroupID = "22477669"
    }

    /// Pro stays out of sight until its first feature (supply, phase 4) ships with it. Debug builds can show it
    /// with the `-proStore` launch argument, or the `proStore` user default (for Xcode runs, which use the local
    /// StoreKit configuration but no launch arguments).
    static var isStoreVisible: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-proStore") || UserDefaults.standard.bool(forKey: "proStore")
        #else
        false
        #endif
    }

    nonisolated enum Plan: Equatable {
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
    nonisolated struct Entitlement: Equatable {
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
    nonisolated struct EntitlementCandidate: Equatable {
        let productID: String
        let revocationDate: Date?
        let expirationDate: Date?
        let isUpgraded: Bool
        let isFamilyShared: Bool
        var isTrial: Bool = false
    }

    private(set) var entitlement: Entitlement?
    /// The three products, once loaded (yearly, monthly, lifetime). Empty offline or before `loadProducts()`.
    private(set) var products: [Product] = []
    /// False until the first entitlement check finishes, so the UI doesn't flash "free" for a Pro user at launch.
    private(set) var hasCheckedEntitlements = false

    var isPro: Bool { entitlement != nil }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Started at launch, as Apple asks: renewals, refunds, Ask to Buy approvals and purchases from other
        // devices arrive here, even while no Pro screen is open.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Entitlement

    /// Re-reads the current entitlements. Unverified transactions never count.
    func refreshEntitlement() async {
        var transactions: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            transactions.append(transaction)
        }
        var found = Self.entitlement(from: transactions.map(EntitlementCandidate.init))
        // Whether the winning subscription renews lives in its renewal info, not the transaction.
        if let current = found, current.plan != .lifetime,
           let transaction = transactions.first(where: { candidate in
               // The transaction the entitlement came from: same plan and ownership, still valid.
               Plan(productID: candidate.productID) == current.plan
                   && (candidate.ownershipType == .familyShared) == current.isFamilyShared
                   && candidate.revocationDate == nil && !candidate.isUpgraded
           }),
           let status = await transaction.subscriptionStatus,
           case .verified(let renewal) = status.renewalInfo {
            found?.willAutoRenew = renewal.willAutoRenew
        }
        entitlement = found
        hasCheckedEntitlements = true
        // Refill reminders (supply) are Pro: the scheduler follows the entitlement.
        NotificationService.supplyRemindersEnabled = Self.isStoreVisible && found != nil
    }

    /// The rule, kept pure: revoked (refunded) and upgraded-away transactions don't count, nor an expired
    /// subscription; lifetime beats any subscription, yearly beats monthly; own purchases beat family-shared ones.
    nonisolated static func entitlement(from candidates: [EntitlementCandidate], now: Date = .now) -> Entitlement? {
        let valid = candidates.filter { candidate in
            candidate.revocationDate == nil && !candidate.isUpgraded
                && (candidate.expirationDate.map { $0 > now } ?? true)
                && Plan(productID: candidate.productID) != nil
        }
        func rank(_ candidate: EntitlementCandidate) -> Int {
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

    // MARK: - Store

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: ProductID.all)) ?? []
        products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
    }

    func product(_ plan: Plan) -> Product? {
        products.first { Plan(productID: $0.id) == plan }
    }

    nonisolated enum PurchaseOutcome: Equatable {
        case purchased
        /// Waiting for approval (Ask to Buy, a bank check); the update arrives through `Transaction.updates`.
        case pending
        case cancelled
        /// Bought but not verifiable on this device (or an outcome StoreKit added later): nothing unlocked, and
        /// the paywall says so rather than looking like the user backed out.
        case failed
    }

    /// Buys a product. A verified transaction is finished and unlocks Pro straight away.
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        switch try await product.purchase() {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refreshEntitlement()
            return .purchased
        case .success(.unverified):
            // StoreKit couldn't verify it on the device; it doesn't unlock anything.
            await refreshEntitlement()
            return .failed
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .failed
        }
    }

    /// Restore purchases: asks the App Store for this Apple Account's transactions (it may ask the user to sign
    /// in), then re-reads the entitlement. StoreKit 2 normally keeps them in sync on its own.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }
}

extension ProAccess.EntitlementCandidate {
    init(_ transaction: Transaction) {
        self.init(productID: transaction.productID,
                  revocationDate: transaction.revocationDate,
                  expirationDate: transaction.expirationDate,
                  isUpgraded: transaction.isUpgraded,
                  isFamilyShared: transaction.ownershipType == .familyShared,
                  isTrial: transaction.offer?.type == .introductory)
    }
}
