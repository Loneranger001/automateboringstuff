import Foundation

/// Pure, stateless portfolio math utilities.
/// No I/O — fully unit-testable.
enum PortfolioCalculator {

    // MARK: - FX-aware aggregation

    /// Per-account native value (positions + cash) converted to `baseCurrency`.
    /// The group's accounts can be in different currencies (e.g. a CAD TFSA and
    /// a USD non-registered account) — summing their raw values gives a wrong
    /// total labeled with the base currency's symbol. Convert each account's
    /// native value to the base currency first.
    static func accountValueInBase(
        _ account: Account,
        baseCurrency: Currency,
        usdCadRate: Double
    ) -> (marketValue: Double, cash: Double) {
        let raw = account.totalMarketValue
        let cash = account.cashBalance
        let rate = conversionRate(from: account.currency, to: baseCurrency, usdCadRate: usdCadRate)
        return (raw * rate, cash * rate)
    }

    /// Group total (market value + cash) in base currency.
    static func totalValueInBase(
        group: PortfolioGroup,
        usdCadRate: Double
    ) -> Double {
        group.accounts.reduce(0) { acc, account in
            let v = accountValueInBase(account, baseCurrency: group.baseCurrency, usdCadRate: usdCadRate)
            return acc + v.marketValue + v.cash
        }
    }

    /// Group cash in base currency.
    static func totalCashInBase(
        group: PortfolioGroup,
        usdCadRate: Double
    ) -> Double {
        group.accounts.reduce(0) { acc, account in
            let v = accountValueInBase(account, baseCurrency: group.baseCurrency, usdCadRate: usdCadRate)
            return acc + v.cash
        }
    }

    /// Conversion factor for `1 unit of from` expressed in `to`, for the USD/CAD
    /// pair. `usdCadRate` is how many CAD equal 1 USD.
    static func conversionRate(from: Currency, to: Currency, usdCadRate: Double) -> Double {
        if from == to { return 1.0 }
        switch (from, to) {
        case (.usd, .cad): return usdCadRate
        case (.cad, .usd): return usdCadRate > 0 ? 1.0 / usdCadRate : 1.0
        default: return 1.0
        }
    }

    // MARK: - Portfolio Accuracy

    /// Returns a value 0.0–1.0 representing how close the current holdings are to targets.
    /// 1.0 = perfectly on target. 0.0 = completely off target.
    ///
    /// Formula: 1 - Σ|actual_weight - target_weight| / 2
    static func accuracy(
        holdings: [(securityId: UUID, currentValue: Double)],
        targets: [(securityId: UUID, targetPercent: Double)],
        totalValue: Double
    ) -> Double {
        guard totalValue > 0 else { return 0 }

        var totalDeviation = 0.0
        for target in targets {
            let currentValue = holdings.first(where: { $0.securityId == target.securityId })?.currentValue ?? 0
            let actualWeight = currentValue / totalValue
            totalDeviation += abs(actualWeight - target.targetPercent)
        }
        // Also account for untracked holdings (holdings not in targets)
        for holding in holdings {
            if !targets.contains(where: { $0.securityId == holding.securityId }) {
                let actualWeight = holding.currentValue / totalValue
                totalDeviation += actualWeight
            }
        }

        return max(0, 1 - totalDeviation / 2)
    }

    // MARK: - Drift Detection

    /// Returns true if any individual allocation has drifted by more than `threshold` from its target.
    static func hasDrifted(
        holdings: [(securityId: UUID, currentValue: Double)],
        targets: [(securityId: UUID, targetPercent: Double)],
        totalValue: Double,
        threshold: Double
    ) -> Bool {
        guard totalValue > 0 else { return false }
        for target in targets {
            let currentValue = holdings.first(where: { $0.securityId == target.securityId })?.currentValue ?? 0
            let actualWeight = currentValue / totalValue
            if abs(actualWeight - target.targetPercent) > threshold { return true }
        }
        return false
    }

    // MARK: - Current Weights

    struct AllocationWeight {
        let securityId: UUID
        let symbol: String
        let currentValue: Double
        let currentWeight: Double   // fraction of total
        let targetWeight: Double    // fraction of total (from target allocation)
        let driftPercent: Double    // (currentWeight - targetWeight), can be negative
    }

    static func weights(
        holdings: [(securityId: UUID, symbol: String, currentValue: Double)],
        targets: [(securityId: UUID, symbol: String, targetPercent: Double)],
        totalValue: Double
    ) -> [AllocationWeight] {
        var result: [AllocationWeight] = []

        // Targets that may or may not have a current holding
        for target in targets {
            let currentValue = holdings.first(where: { $0.securityId == target.securityId })?.currentValue ?? 0
            let currentWeight = totalValue > 0 ? currentValue / totalValue : 0
            result.append(AllocationWeight(
                securityId: target.securityId,
                symbol: target.symbol,
                currentValue: currentValue,
                currentWeight: currentWeight,
                targetWeight: target.targetPercent,
                driftPercent: currentWeight - target.targetPercent
            ))
        }
        return result
    }

    // MARK: - Performance: Modified Dietz TWR

    struct SnapshotPoint {
        let date: Date
        let totalValue: Double
        let periodContributions: Double   // net contributions DURING this period (not cumulative)
    }

    /// Calculates time-weighted return using the Modified Dietz method.
    /// Returns a fraction (e.g. 0.12 = 12% return).
    ///
    /// Modified Dietz formula per period:
    ///   R = (EMV - BMV - CF) / (BMV + CF * W)
    /// where W = 0.5 (contributions assumed mid-period).
    static func timeWeightedReturn(snapshots: [SnapshotPoint]) -> Double {
        guard snapshots.count >= 2 else { return 0 }

        var compoundReturn = 1.0
        for i in 1..<snapshots.count {
            let prev = snapshots[i - 1]
            let curr = snapshots[i]
            let bmv = prev.totalValue
            let emv = curr.totalValue
            let cf  = curr.periodContributions
            let denominator = bmv + cf * 0.5
            guard denominator > 0 else { continue }
            let periodReturn = (emv - bmv - cf) / denominator
            compoundReturn *= (1 + periodReturn)
        }
        return compoundReturn - 1
    }

    // MARK: - Total absolute return

    /// Simple total return: (current - invested) / invested
    static func totalReturn(currentValue: Double, netContributions: Double) -> Double {
        guard netContributions > 0 else { return 0 }
        return (currentValue - netContributions) / netContributions
    }
}
