import XCTest
@testable import PassivMac

final class RebalanceEngineTests: XCTestCase {

    // MARK: - Helpers

    let vfvId = UUID()
    let xawId = UUID()
    let zagId = UUID()

    func makeInput(
        holdings: [(UUID, Double)] = [],
        cash: Double,
        prices: [UUID: Double],
        targetAllocations: [(UUID, String, Double)],
        accountAssignments: [UUID: UUID]? = nil,
        mode: RebalanceMode = .buyOnly
    ) -> RebalanceEngine.Input {
        let defaultAccount = UUID()
        let assignments = accountAssignments ?? Dictionary(
            uniqueKeysWithValues: targetAllocations.map { ($0.0, defaultAccount) }
        )
        return RebalanceEngine.Input(
            targetAllocations: targetAllocations.map { ($0.0, $0.1, $0.2) },
            currentHoldings: holdings.map { ($0.0, $0.1) },
            availableCash: cash,
            currentPrices: prices,
            accountAssignments: assignments,
            mode: mode
        )
    }

    // MARK: - Basic buy-only

    func testBuyOnlySingleSecurity() {
        // $10,000 cash, 100% VFV at $100/share → buy 100 shares
        let input = makeInput(
            cash: 10_000,
            prices: [vfvId: 100],
            targetAllocations: [(vfvId, "VFV", 1.0)]
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertEqual(trades.count, 1)
        XCTAssertEqual(trades[0].action, .buy)
        XCTAssertEqual(trades[0].quantity, 100)
        XCTAssertEqual(trades[0].estimatedCost, 10_000)
    }

    func testBuyOnlyThreeSecurities() {
        // $30,000 cash, 40/40/20 split, prices $100/$50/$200
        // VFV: 40% of 30k = $12,000 → 120 shares
        // XAW: 40% of 30k = $12,000 → 240 shares
        // ZAG: 20% of 30k = $6,000 → 30 shares
        let input = makeInput(
            cash: 30_000,
            prices: [vfvId: 100, xawId: 50, zagId: 200],
            targetAllocations: [
                (vfvId, "VFV", 0.40),
                (xawId, "XAW", 0.40),
                (zagId, "ZAG", 0.20),
            ]
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertEqual(trades.count, 3)

        let vfv = trades.first(where: { $0.symbol == "VFV" })
        let xaw = trades.first(where: { $0.symbol == "XAW" })
        let zag = trades.first(where: { $0.symbol == "ZAG" })

        XCTAssertEqual(vfv?.quantity, 120)
        XCTAssertEqual(xaw?.quantity, 240)
        XCTAssertEqual(zag?.quantity, 30)
    }

    // MARK: - Cash scaling

    func testBuyFitsWithinCashWithoutScaling() {
        // $750 cash, 50/50 VFV+XAW at $100 each.
        // totalPortfolioValue = $750, target = $375 each → floor(375/100) = 3 shares each = $300 each = $600 total.
        // $600 < $750 → scaling does NOT trigger; all shares purchased.
        let input = makeInput(
            cash: 750,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)]
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertEqual(trades.count, 2)
        XCTAssertEqual(trades.first(where: { $0.symbol == "VFV" })?.quantity, 3)
        XCTAssertEqual(trades.first(where: { $0.symbol == "XAW" })?.quantity, 3)
        let totalCost = trades.reduce(0) { $0 + $1.estimatedCost }
        XCTAssertLessThanOrEqual(totalCost, 750)
    }

    func testScalesDownProportionallyWhenCashShort() {
        // Existing VFV holding inflates totalPortfolioValue so XAW delta > available cash.
        //
        // Holdings: VFV $6,000 (held, not being sold in buy-only mode)
        // Cash: $1,000
        // Targets: VFV 20%, XAW 80%  at $100/share
        //
        // totalPortfolioValue = 6,000 + 1,000 = 7,000
        // VFV: target = 0.20 * 7,000 = $1,400, current = $6,000, delta = -$4,600 → skip (buy-only)
        // XAW: target = 0.80 * 7,000 = $5,600, current = $0, delta = $5,600
        //      raw qty = floor(5600 / 100) = 56 shares, raw cost = $5,600
        //
        // Scaling: totalBuyCost ($5,600) > availableCash ($1,000)
        //   scaleFactor = 1000 / 5600 ≈ 0.1786
        //   scaledQty   = floor(56 * 0.1786) = floor(10.0) = 10 shares
        //   scaledCost  = 10 * $100 = $1,000
        let input = makeInput(
            holdings: [(vfvId, 6_000)],
            cash: 1_000,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.20), (xawId, "XAW", 0.80)],
            mode: .buyOnly
        )
        let trades = RebalanceEngine.calculate(input)

        // Only XAW should be bought (VFV is overweight, skipped in buy-only)
        XCTAssertEqual(trades.count, 1)
        let xawTrade = try! XCTUnwrap(trades.first(where: { $0.symbol == "XAW" }))
        XCTAssertEqual(xawTrade.action, .buy)
        XCTAssertEqual(xawTrade.quantity, 10)
        XCTAssertEqual(xawTrade.estimatedCost, 1_000)

        // Total cost must not exceed available cash
        let totalCost = trades.reduce(0) { $0 + $1.estimatedCost }
        XCTAssertLessThanOrEqual(totalCost, 1_000)
    }

    // MARK: - Buy-only: no sell orders generated

    func testBuyOnlyNeverGeneratesSell() {
        // VFV is 80% of portfolio but target is 50% → should NOT sell in buy-only mode.
        // XAW is underweight (0%) vs 50% target → one buy order expected.
        // totalPortfolioValue = 8,000 + 1,000 = 9,000
        // XAW: target = 4,500, delta = 4,500, raw qty = 45, raw cost = $4,500
        // Scaling: 4,500 > 1,000 → scaleFactor = 1000/4500 = 2/9
        //   scaledQty = floor(45 * 2/9) = floor(10.0) = 10 shares
        let input = makeInput(
            holdings: [(vfvId, 8_000)],
            cash: 1_000,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)],
            mode: .buyOnly
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertFalse(trades.isEmpty, "Expected at least one buy order for underweight XAW")
        XCTAssertTrue(trades.allSatisfy { $0.action == .buy }, "Buy-only mode must not produce sell orders")
        XCTAssertNil(trades.first(where: { $0.symbol == "VFV" }), "Overweight VFV must not appear as a buy")
    }

    // MARK: - Full rebalance

    func testFullRebalanceGeneratesSell() {
        // VFV is 80% of portfolio but target is 50% → should SELL in full rebalance mode
        let input = makeInput(
            holdings: [(vfvId, 8_000), (xawId, 2_000)],
            cash: 0,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)],
            mode: .fullRebalance
        )
        let trades = RebalanceEngine.calculate(input)
        let sells = trades.filter { $0.action == .sell }
        let buys  = trades.filter { $0.action == .buy  }
        XCTAssertFalse(sells.isEmpty, "Expected sell orders in full rebalance mode")
        XCTAssertFalse(buys.isEmpty,  "Expected buy orders in full rebalance mode")
    }

    // MARK: - Edge cases

    func testEmptyPortfolioNoCash() {
        let input = makeInput(
            cash: 0,
            prices: [vfvId: 100],
            targetAllocations: [(vfvId, "VFV", 1.0)]
        )
        XCTAssertTrue(RebalanceEngine.calculate(input).isEmpty)
    }

    func testSkipsSecuritiesWithNoPrice() {
        let input = makeInput(
            cash: 10_000,
            prices: [:],  // no prices
            targetAllocations: [(vfvId, "VFV", 1.0)]
        )
        XCTAssertTrue(RebalanceEngine.calculate(input).isEmpty)
    }

    func testSkipsSecuritiesWithNoAccountAssignment() {
        let input = RebalanceEngine.Input(
            targetAllocations: [(vfvId, "VFV", 1.0)],
            currentHoldings: [],
            availableCash: 10_000,
            currentPrices: [vfvId: 100],
            accountAssignments: [:],   // no assignment
            mode: .buyOnly
        )
        XCTAssertTrue(RebalanceEngine.calculate(input).isEmpty)
    }

    func testQuantityIsAlwaysWholeShares() {
        // $1,500 cash, 100% VFV at $110/share → floor(1500/110) = 13 shares
        let input = makeInput(
            cash: 1_500,
            prices: [vfvId: 110],
            targetAllocations: [(vfvId, "VFV", 1.0)]
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertEqual(trades.first?.quantity, 13)
    }

    func testAlreadyBalancedPortfolio() {
        // Portfolio is perfectly on target — should produce no trades (or very small ones)
        let input = makeInput(
            holdings: [(vfvId, 5_000), (xawId, 5_000)],
            cash: 0,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)],
            mode: .buyOnly
        )
        let trades = RebalanceEngine.calculate(input)
        // No cash → no buy orders in buy-only mode
        XCTAssertTrue(trades.isEmpty)
    }
}
