import Foundation
import Observation
import StoreKit
import WidgetKit

/// Whether this person has nutrx Pro, from StoreKit 2 on the device (docs/pro/PLAN.md, phase 3). Reads
/// `Transaction.currentEntitlements` at launch, follows `Transaction.updates` (renewals, refunds, Ask to Buy, a
/// purchase on another device), buys and restores. The entitlement is never stored — not in SwiftData, not in
/// iCloud, not in UserDefaults: it's derived from StoreKit every launch, and no receipt leaves the device.
@MainActor
@Observable
final class ProAccess {
    // The pure parts live in `ProEntitlement`, shared with the widget extension.
    typealias ProductID = ProEntitlement.ProductID
    typealias Plan = ProEntitlement.Plan
    typealias Entitlement = ProEntitlement.Entitlement
    typealias EntitlementCandidate = ProEntitlement.Candidate

    /// nutrx Pro is on now that its first feature (supply, phase 4) has shipped. Kept as one switch, in case Pro
    /// ever has to be hidden again.
    static let isStoreVisible = true

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
        let changed = (entitlement != nil) != (found != nil)
        entitlement = found
        hasCheckedEntitlements = true
        // A purchase, renewal lapse or refund changes what the widget may show (supply is Pro).
        if changed { WidgetCenter.shared.reloadAllTimelines() }
        // Refill reminders (supply) are Pro: the scheduler follows the entitlement.
        NotificationService.supplyRemindersEnabled = Self.isStoreVisible && found != nil
    }

    /// The rule (`ProEntitlement.entitlement(from:now:)`), kept here too for callers and tests.
    nonisolated static func entitlement(from candidates: [EntitlementCandidate], now: Date = .now) -> Entitlement? {
        ProEntitlement.entitlement(from: candidates, now: now)
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
