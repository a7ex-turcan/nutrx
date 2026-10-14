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
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            await pro.refreshEntitlement()
            if !pro.isPro { return }
            try? await Task.sleep(for: .milliseconds(250))
        } while Date() < deadline
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    func testTheThreeProductsLoadWithTheAgreedPrices() async throws {
        session = try makeSession()
        let pro = ProAccess()
        await pro.loadProducts()
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
        await pro.loadProducts()
        await pro.refreshEntitlement()
        XCTAssertFalse(pro.isPro)
        XCTAssertTrue(pro.hasCheckedEntitlements)

        let outcome = try await pro.purchase(XCTUnwrap(pro.product(.yearly)))
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(pro.entitlement?.plan, .yearly)
        XCTAssertNotNil(pro.entitlement?.expirationDate)
    }

    func testASubscriptionThatLapsesLocksProAgain() async throws {
        session = try makeSession()
        session.timeRate = .oneRenewalEveryTwoSeconds
        let pro = ProAccess()
        await pro.loadProducts()
        _ = try await pro.purchase(XCTUnwrap(pro.product(.monthly)))
        XCTAssertEqual(pro.entitlement?.plan, .monthly)

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProAccess.ProductID.monthly })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await waitUntilFree(pro, timeout: 15)
        XCTAssertFalse(pro.isPro, "a cancelled subscription ends with its period")
    }

    func testARefundTakesProAway() async throws {
        session = try makeSession()
        let pro = ProAccess()
        await pro.loadProducts()
        _ = try await pro.purchase(XCTUnwrap(pro.product(.lifetime)))
        XCTAssertEqual(pro.entitlement, .init(plan: .lifetime, expirationDate: nil, isFamilyShared: false))

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProAccess.ProductID.lifetime })
        try session.refundTransaction(identifier: transaction.identifier)
        await waitUntilFree(pro)
        XCTAssertFalse(pro.isPro)
    }

    func testLifetimeOutranksAnActiveSubscription() async throws {
        session = try makeSession()
        let pro = ProAccess()
        await pro.loadProducts()
        _ = try await pro.purchase(XCTUnwrap(pro.product(.monthly)))
        XCTAssertEqual(pro.entitlement?.plan, .monthly)
        _ = try await pro.purchase(XCTUnwrap(pro.product(.lifetime)))
        XCTAssertEqual(pro.entitlement?.plan, .lifetime)
    }

    func testAPurchaseMadeElsewhereIsPickedUpOnRefresh() async throws {
        session = try makeSession()
        let pro = ProAccess()
        // As on another device or after a reinstall: the transaction exists, this ProAccess didn't make it.
        try await session.buyProduct(identifier: ProAccess.ProductID.monthly)
        await pro.refreshEntitlement()
        XCTAssertEqual(pro.entitlement?.plan, .monthly)
    }
}
