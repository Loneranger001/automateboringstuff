import XCTest
@testable import PassivMac

final class PortfolioCalculatorTests: XCTestCase {

    let vfvId = UUID()
    let xawId = UUID()
    let zagId = UUID()

    // MARK: - Accuracy

    func testPerfectAccuracy() {
        let holdings: [(securityId: UUID, currentValue: Double)] = [
            (vfvId, 5_000), (xawId, 5_000)
        ]
        let targets: [(securityId: UUID, targetPercent: Double)] = [
            (vfvId, 0.5), (xawId, 0.5)
        ]
        let acc = PortfolioCalculator.accuracy(holdings: holdings, targets: targets, totalValue: 10_000)
        XCTAssertEqual(acc, 1.0, accuracy: 0.001)
    }

    func testZeroAccuracyCompleteMismatch() {
        // All money in VFV but target is 100% XAW
        let holdings: [(securityId: UUID, currentValue: Double)] = [(vfvId, 10_000)]
        let targets: [(securityId: UUID, targetPercent: Double)] = [(xawId, 1.0)]
        let acc = PortfolioCalculator.accuracy(holdings: holdings, targets: targets, totalValue: 10_000)
        // Deviation: XAW actual=0, target=1.0 → |0-1|=1.0; VFV not in targets → adds 1.0
        // total deviation = 2.0, accuracy = 1 - 2/2 = 0
        XCTAssertEqual(acc, 0.0, accuracy: 0.001)
    }

    func testPartialAccuracy() {
        // VFV: 60% actual, 50% target → drift 0.10
        // XAW: 40% actual, 50% target → drift 0.10
        // total deviation = 0.20, accuracy = 1 - 0.20/2 = 0.90
        let holdings: [(securityId: UUID, currentValue: Double)] = [
            (vfvId, 6_000), (xawId, 4_000)
        ]
        let targets: [(securityId: UUID, targetPercent: Double)] = [
            (vfvId, 0.5), (xawId, 0.5)
        ]
        let acc = PortfolioCalculator.accuracy(holdings: holdings, targets: targets, totalValue: 10_000)
        XCTAssertEqual(acc, 0.90, accuracy: 0.001)
    }

    func testZeroTotalValue() {
        let acc = PortfolioCalculator.accuracy(holdings: [], targets: [(vfvId, 1.0)], totalValue: 0)
        XCTAssertEqual(acc, 0)
    }

    // MARK: - Drift Detection

    func testNoDriftWithinThreshold() {
        let holdings: [(securityId: UUID, currentValue: Double)] = [(vfvId, 5_200), (xawId, 4_800)]
        let targets: [(securityId: UUID, targetPercent: Double)] = [(vfvId, 0.5), (xawId, 0.5)]
        // Max drift = 2% — below 5% threshold
        XCTAssertFalse(
            PortfolioCalculator.hasDrifted(holdings: holdings, targets: targets, totalValue: 10_000, threshold: 0.05)
        )
    }

    func testDriftExceedsThreshold() {
        let holdings: [(securityId: UUID, currentValue: Double)] = [(vfvId, 6_500), (xawId, 3_500)]
        let targets: [(securityId: UUID, targetPercent: Double)] = [(vfvId, 0.5), (xawId, 0.5)]
        // VFV drift = 15% — above 5% threshold
        XCTAssertTrue(
            PortfolioCalculator.hasDrifted(holdings: holdings, targets: targets, totalValue: 10_000, threshold: 0.05)
        )
    }

    // MARK: - Weights

    func testWeightsCalculation() {
        let holdings: [(securityId: UUID, symbol: String, currentValue: Double)] = [
            (vfvId, "VFV", 4_000), (xawId, "XAW", 6_000)
        ]
        let targets: [(securityId: UUID, symbol: String, targetPercent: Double)] = [
            (vfvId, "VFV", 0.5), (xawId, "XAW", 0.5)
        ]
        let weights = PortfolioCalculator.weights(holdings: holdings, targets: targets, totalValue: 10_000)
        let vfw = weights.first(where: { $0.securityId == vfvId })
        XCTAssertEqual(vfw?.currentWeight ?? 0, 0.40, accuracy: 0.001)
        XCTAssertEqual(vfw?.driftPercent ?? 0, -0.10, accuracy: 0.001)
    }

    // MARK: - Time-Weighted Return

    func testTWRZeroWithSinglePoint() {
        let points = [PortfolioCalculator.SnapshotPoint(date: Date(), totalValue: 10_000, periodContributions: 0)]
        XCTAssertEqual(PortfolioCalculator.timeWeightedReturn(snapshots: points), 0)
    }

    func testTWRPositiveReturn() {
        let now = Date()
        let points = [
            PortfolioCalculator.SnapshotPoint(date: now.addingTimeInterval(-86400), totalValue: 10_000, periodContributions: 0),
            PortfolioCalculator.SnapshotPoint(date: now,                            totalValue: 11_000, periodContributions: 0),
        ]
        // 10% return, no contributions
        XCTAssertEqual(PortfolioCalculator.timeWeightedReturn(snapshots: points), 0.10, accuracy: 0.001)
    }

    func testTWRWithContribution() {
        let now = Date()
        let points = [
            PortfolioCalculator.SnapshotPoint(date: now.addingTimeInterval(-86400), totalValue: 10_000, periodContributions: 0),
            PortfolioCalculator.SnapshotPoint(date: now,                            totalValue: 15_000, periodContributions: 5_000),
        ]
        // Denominator = 10_000 + 5_000*0.5 = 12_500
        // Return = (15_000 - 10_000 - 5_000) / 12_500 = 0
        XCTAssertEqual(PortfolioCalculator.timeWeightedReturn(snapshots: points), 0, accuracy: 0.001)
    }

    // MARK: - Total Return

    func testTotalReturn() {
        let r = PortfolioCalculator.totalReturn(currentValue: 12_000, netContributions: 10_000)
        XCTAssertEqual(r, 0.20, accuracy: 0.001)
    }

    func testTotalReturnZeroContributions() {
        XCTAssertEqual(PortfolioCalculator.totalReturn(currentValue: 12_000, netContributions: 0), 0)
    }
}
