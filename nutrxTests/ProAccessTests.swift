import StoreKit
import StoreKitTest
import XCTest
@testable import nutrx

/// nutrx Pro: which transactions unlock it (pure), and buying / expiry / refunds / lifetime against the local
/// StoreKit configuration (`StoreKit/nutrxPro.storekit`, the same products as App Store Connect).
@MainActor
final class ProAccessTests: XCTestCase {
    private typealias Candidate = ProAccess.EntitlementCandidate
    private let now = Date(timeIntervalSince1970: 1_791_965_100)

    private func candidate(_ id: String, expires: Date? = nil, revoked: Bool = false, upgraded: Bool = false,
                           family: Bool = false) -> Candidate {
        Candidate(productID: id, revocationDate: revoked ? now.addingTimeInterval(-60) : nil,
                  expirationDate: expires, isUpgraded: upgraded, isFamilyShared: family)
    }

    // MARK: - The rule

    func testNothingMeansFree() {
        XCTAssertNil(ProAccess.entitlement(from: [], now: now))
    }

    func testAnActiveSubscriptionUnlocksPro() {
        let renews = now.addingTimeInterval(86_400 * 300)
        XCTAssertEqual(ProAccess.entitlement(from: [candidate(ProAccess.ProductID.yearly, expires: renews)], now: now),
                       .init(plan: .yearly, expirationDate: renews, isFamilyShared: false))
    }

    func testExpiredRefundedAndUpgradedAwayDontCount() {
        let past = now.addingTimeInterval(-1)
        let future = now.addingTimeInterval(86_400)
        XCTAssertNil(ProAccess.entitlement(from: [candidate(ProAccess.ProductID.monthly, expires: past)], now: now))
        XCTAssertNil(ProAccess.entitlement(from: [candidate(ProAccess.ProductID.lifetime, revoked: true)], now: now))
        XCTAssertNil(ProAccess.entitlement(from: [candidate(ProAccess.ProductID.monthly, expires: future, upgraded: true)],
                                           now: now))
    }

    func testUnknownProductsDontCount() {
        XCTAssertNil(ProAccess.entitlement(from: [candidate("nutrx.something.else")], now: now))
    }

    func testLifetimeBeatsSubscriptionsAndOwnBeatsFamilyShared() {
        let future = now.addingTimeInterval(86_400)
        let mixed = [candidate(ProAccess.ProductID.yearly, expires: future),
                     candidate(ProAccess.ProductID.lifetime, family: true),
                     candidate(ProAccess.ProductID.lifetime)]
        XCTAssertEqual(ProAccess.entitlement(from: mixed, now: now),
                       .init(plan: .lifetime, expirationDate: nil, isFamilyShared: false))
        let yearlyAndMonthly = [candidate(ProAccess.ProductID.monthly, expires: future),
                                candidate(ProAccess.ProductID.yearly, expires: future, family: true)]
        XCTAssertEqual(ProAccess.entitlement(from: yearlyAndMonthly, now: now)?.plan, .yearly)
    }

    func testAFamilySharedPurchaseStillUnlocksPro() {
        XCTAssertEqual(ProAccess.entitlement(from: [candidate(ProAccess.ProductID.lifetime, family: true)], now: now),
                       .init(plan: .lifetime, expirationDate: nil, isFamilyShared: true))
    }

    // MARK: - StoreKitTest

    private var session: SKTestSession!

    private func makeSession() throws -> SKTestSession {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/nutrxPro.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Expiry and refunds reach `currentEntitlements` a moment after the session call.
    private func waitUntilFree(_ pro: ProAccess, timeout: TimeInterval = 10) async {
        await waitUntil(pro, timeout: timeout) { !$0.isPro }
    }

    /// Refreshes until `condition` holds or `timeout` passes: StoreKitTest reports purchases made through the session
    /// (another device, a refund, an expiry) a moment after the call, not straight away (#121).
    private func waitUntil(_ pro: ProAccess, timeout: TimeInterval = 10, _ condition: (ProAccess) -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            await pro.refreshEntitlement()
            if condition(pro) { return }
            try? await Task.sleep(for: .milliseconds(250))
        } while Date() < deadline
    }

    private struct StoreKitTimedOut: Error, CustomStringConvertible {
        let seconds: Double
        var description: String { "a StoreKitTest call didn't return within \(Int(seconds)) s" }
    }

    /// Runs a StoreKitTest call with a deadline, so one that never returns fails its test instead of hanging the
    /// whole run (#121). The stuck call is left behind; the test moves on.
    private func withDeadline<T: Sendable>(_ seconds: Double = 20,
                                           _ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = ResumeOnce()
            Task { @MainActor in
                do {
                    let value = try await operation()
                    if resumed.claim() { continuation.resume(returning: value) }
                } catch {
                    if resumed.claim() { continuation.resume(throwing: error) }
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                if resumed.claim() { continuation.resume(throwing: StoreKitTimedOut(seconds: seconds)) }
            }
        }
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    func testTheThreeProductsLoadWithTheAgreedPrices() async throws {
        session = try makeSession()
        let pro = ProAccess()
        try await withDeadline { await pro.loadProducts() }
        XCTAssertEqual(pro.products.map(\.id), ["nutrx.pro.yearly", "nutrx.pro.monthly", "nutrx.pro.lifetime"])
        // displayPrice, not price: StoreKitTest reads the file's prices with the simulator's locale.
        XCTAssertTrue(pro.product(.yearly)?.displayPrice.contains("14") ?? false)
        XCTAssertTrue(pro.product(.yearly)?.displayPrice.contains("99") ?? false)
        XCTAssertTrue(pro.product(.monthly)?.displayPrice.contains("1") ?? false)
        XCTAssertTrue(pro.product(.lifetime)?.displayPrice.contains("29") ?? false)
        XCTAssertEqual(pro.product(.yearly)?.type, .autoRenewable)
        XCTAssertEqual(pro.product(.lifetime)?.type, .nonConsumable)
        let trial = try XCTUnwrap(pro.product(.yearly)?.subscription?.introductoryOffer)
        XCTAssertEqual(trial.paymentMode, .freeTrial)
        XCTAssertEqual(trial.period.unit, .week)
        XCTAssertEqual(trial.period.value, 1)
        XCTAssertNil(pro.product(.monthly)?.subscription?.introductoryOffer, "the trial is on yearly only")
    }

    func testBuyingYearlyUnlocksPro() async throws {
        session = try makeSession()
        let pro = ProAccess()
        try await withDeadline { await pro.loadProducts() }
        await pro.refreshEntitlement()
        XCTAssertFalse(pro.isPro)
        XCTAssertTrue(pro.hasCheckedEntitlements)

        let yearly = try XCTUnwrap(pro.product(.yearly))
        let outcome = try await withDeadline { try await pro.purchase(yearly) }
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(pro.entitlement?.plan, .yearly)
        XCTAssertNotNil(pro.entitlement?.expirationDate)
        XCTAssertEqual(pro.entitlement?.isTrial, true, "a first yearly purchase starts with the free week")
        XCTAssertEqual(pro.entitlement?.willAutoRenew, true)
    }

    func testASubscriptionThatLapsesLocksProAgain() async throws {
        session = try makeSession()
        session.timeRate = .oneRenewalEveryTwoSeconds
        let pro = ProAccess()
        try await withDeadline { await pro.loadProducts() }
        let monthly = try XCTUnwrap(pro.product(.monthly))
        _ = try await withDeadline { try await pro.purchase(monthly) }
        XCTAssertEqual(pro.entitlement?.plan, .monthly)

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProAccess.ProductID.monthly })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await waitUntilFree(pro, timeout: 15)
        XCTAssertFalse(pro.isPro, "a cancelled subscription ends with its period")
    }

    func testARefundTakesProAway() async throws {
        session = try makeSession()
        let pro = ProAccess()
        try await withDeadline { await pro.loadProducts() }
        let lifetime = try XCTUnwrap(pro.product(.lifetime))
        _ = try await withDeadline { try await pro.purchase(lifetime) }
        XCTAssertEqual(pro.entitlement, .init(plan: .lifetime, expirationDate: nil, isFamilyShared: false))

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProAccess.ProductID.lifetime })
        try session.refundTransaction(identifier: transaction.identifier)
        await waitUntilFree(pro)
        XCTAssertFalse(pro.isPro)
    }

    func testLifetimeOutranksAnActiveSubscription() async throws {
        session = try makeSession()
        let pro = ProAccess()
        try await withDeadline { await pro.loadProducts() }
        let monthly = try XCTUnwrap(pro.product(.monthly))
        let lifetime = try XCTUnwrap(pro.product(.lifetime))
        _ = try await withDeadline { try await pro.purchase(monthly) }
        XCTAssertEqual(pro.entitlement?.plan, .monthly)
        _ = try await withDeadline { try await pro.purchase(lifetime) }
        XCTAssertEqual(pro.entitlement?.plan, .lifetime)
    }

    func testRestoreFindsAPurchaseMadeElsewhere() async throws {
        session = try makeSession()
        let pro = ProAccess()
        let session = try XCTUnwrap(self.session)
        try await withDeadline { try await session.buyProduct(identifier: ProAccess.ProductID.lifetime) }
        // AppStore.sync() against the test session, then a fresh entitlement check.
        try await withDeadline { try await pro.restore() }
        XCTAssertEqual(pro.entitlement?.plan, .lifetime)
    }

    func testAPurchaseMadeElsewhereIsPickedUpOnRefresh() async throws {
        session = try makeSession()
        let pro = ProAccess()
        // As on another device or after a reinstall: the transaction exists, this ProAccess didn't make it.
        let session = try XCTUnwrap(self.session)
        try await withDeadline { try await session.buyProduct(identifier: ProAccess.ProductID.monthly) }
        // It reaches currentEntitlements a moment later, not straight away (the flaky part of #121).
        await waitUntil(pro) { $0.entitlement?.plan == .monthly }
        XCTAssertEqual(pro.entitlement?.plan, .monthly)
    }
}

/// Lets exactly one of `withDeadline`'s two tasks resume its continuation.
@MainActor
private final class ResumeOnce {
    private var done = false

    func claim() -> Bool {
        guard !done else { return false }
        done = true
        return true
    }
}
