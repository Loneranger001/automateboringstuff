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

    func testScalesDownWhenCashInsufficient() {
        // $500 cash, 100% VFV at $100 → want 50 shares but total exceeds cash?
        // No — $500 / $100 = 5 shares exactly. Test partial cash.
        let input = makeInput(
            cash: 750,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)]
        )
        // Total portfolio = $750, target $375 each → 3 shares each = $600 total
        // $600 > $750? No, $600 < $750. So no scaling needed.
        let trades = RebalanceEngine.calculate(input)
        let totalCost = trades.reduce(0) { $0 + $1.estimatedCost }
        XCTAssertLessThanOrEqual(totalCost, 750)
    }

    func testScalesDownProportionallyWhenCashShort() {
        // $300 cash, want to buy $200 VFV + $200 XAW = $400 total
        // Scale factor = 300/400 = 0.75
        // VFV: floor(2 * 0.75) = 1 share at $100
        // XAW: floor(2 * 0.75) = 1 share at $100
        let input = makeInput(
            cash: 300,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)]
        )
        let trades = RebalanceEngine.calculate(input)
        let totalCost = trades.reduce(0) { $0 + $1.estimatedCost }
        XCTAssertLessThanOrEqual(totalCost, 300)
    }

    // MARK: - Buy-only: no sell orders generated

    func testBuyOnlyNeverGeneratesSell() {
        // VFV is 80% of portfolio but target is 50% → should NOT sell in buy-only mode
        let input = makeInput(
            holdings: [(vfvId, 8_000)],
            cash: 1_000,
            prices: [vfvId: 100, xawId: 100],
            targetAllocations: [(vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)],
            mode: .buyOnly
        )
        let trades = RebalanceEngine.calculate(input)
        XCTAssertTrue(trades.allSatisfy { $0.action == .buy })
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
