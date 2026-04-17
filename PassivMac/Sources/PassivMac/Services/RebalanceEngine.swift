import Foundation

/// Pure, stateless rebalancing calculator.
/// No I/O — fully unit-testable with no SwiftData or network dependencies.
///
/// Usage:
///   let instructions = RebalanceEngine.calculate(input)
enum RebalanceEngine {

    // MARK: - Types

    struct Input {
        /// Each target allocation: (securityId, targetPercent 0.0–1.0)
        let targetAllocations: [(securityId: UUID, symbol: String, targetPercent: Double)]
        /// Current holdings valued in base currency: (securityId, currentValue)
        let currentHoldings: [(securityId: UUID, currentValue: Double)]
        /// Available cash in base currency across all accounts in the group
        let availableCash: Double
        /// Current price per share in base currency, keyed by securityId
        let currentPrices: [UUID: Double]
        /// Which account to assign each security's trade to (securityId -> accountId)
        /// If not present, the engine will not generate a trade for that security
        let accountAssignments: [UUID: UUID]
        let mode: RebalanceMode
    }

    struct TradeInstruction: Identifiable {
        let id: UUID
        let securityId: UUID
        let symbol: String
        let targetAccountId: UUID
        let action: TradeAction
        /// Whole-share quantity (fractional shares not supported)
        let quantity: Double
        let estimatedPrice: Double
        let estimatedCost: Double

        init(
            securityId: UUID,
            symbol: String,
            targetAccountId: UUID,
            action: TradeAction,
            quantity: Double,
            estimatedPrice: Double
        ) {
            self.id = UUID()
            self.securityId = securityId
            self.symbol = symbol
            self.targetAccountId = targetAccountId
            self.action = action
            self.quantity = quantity
            self.estimatedPrice = estimatedPrice
            self.estimatedCost = quantity * estimatedPrice
        }
    }

    // MARK: - Calculation

    static func calculate(_ input: Input) -> [TradeInstruction] {
        let totalCurrentValue = input.currentHoldings.reduce(0) { $0 + $1.currentValue }
        let totalPortfolioValue = totalCurrentValue + input.availableCash

        // Non-positive portfolio value (no funds + no holdings, or corrupted negative values)
        // → nothing to rebalance. Negative values are treated the same as zero; upstream
        // validation should catch data corruption before it reaches here.
        guard totalPortfolioValue > 0 else { return [] }
        // Cash itself cannot be negative — guard against floating-point noise / bad input.
        let availableCash = max(input.availableCash, 0)

        // Validate target allocations: percents must be in [0, 1] and finite.
        // Sum is allowed to be slightly off from 1.0 (the UI warns at save time);
        // we just skip obviously invalid entries here.
        let validAllocations = input.targetAllocations.filter {
            $0.targetPercent.isFinite && $0.targetPercent >= 0 && $0.targetPercent <= 1
        }

        // Target value for each allocation
        var deltas: [(securityId: UUID, symbol: String, delta: Double, price: Double)] = []

        for allocation in validAllocations {
            // Skip if no usable price (missing, zero, negative, NaN, or infinite).
            guard let price = input.currentPrices[allocation.securityId],
                  price.isFinite, price > 0 else { continue }
            guard input.accountAssignments[allocation.securityId] != nil else { continue }

            let targetValue = allocation.targetPercent * totalPortfolioValue
            let currentValue = input.currentHoldings.first(where: { $0.securityId == allocation.securityId })?.currentValue ?? 0
            let delta = targetValue - currentValue

            guard delta.isFinite else { continue }
            deltas.append((allocation.securityId, allocation.symbol, delta, price))
        }

        // Generate raw trade list
        var trades: [TradeInstruction] = []
        for item in deltas {
            guard let accountId = input.accountAssignments[item.securityId] else { continue }

            if item.delta > 0 {
                let qty = (item.delta / item.price).rounded(.down)
                guard qty >= 1 else { continue }
                trades.append(TradeInstruction(
                    securityId: item.securityId,
                    symbol: item.symbol,
                    targetAccountId: accountId,
                    action: .buy,
                    quantity: qty,
                    estimatedPrice: item.price
                ))
            } else if item.delta < 0 && input.mode == .fullRebalance {
                let qty = (abs(item.delta) / item.price).rounded(.down)
                guard qty >= 1 else { continue }
                trades.append(TradeInstruction(
                    securityId: item.securityId,
                    symbol: item.symbol,
                    targetAccountId: accountId,
                    action: .sell,
                    quantity: qty,
                    estimatedPrice: item.price
                ))
            }
        }

        // In buy-only mode, scale down buys proportionally if total cost exceeds available cash
        if input.mode == .buyOnly {
            trades = scaleBuysToAvailableCash(trades, availableCash: availableCash)
        }

        // Distribute leftover cash from rounding loss to the buy with the highest
        // post-rounding undershoot. Prevents a $100+ rounding drag on a $100k portfolio.
        trades = distributeLeftoverCash(trades, availableCash: availableCash, mode: input.mode)

        return trades
    }

    // MARK: - Private

    private static func scaleBuysToAvailableCash(
        _ trades: [TradeInstruction],
        availableCash: Double
    ) -> [TradeInstruction] {
        let totalBuyCost = trades.reduce(0) { $0 + $1.estimatedCost }
        guard totalBuyCost > availableCash, totalBuyCost > 0 else { return trades }

        let scaleFactor = availableCash / totalBuyCost
        guard scaleFactor.isFinite, scaleFactor > 0 else { return [] }
        return trades.compactMap { trade in
            let scaledQty = (trade.quantity * scaleFactor).rounded(.down)
            guard scaledQty >= 1 else { return nil }
            return TradeInstruction(
                securityId: trade.securityId,
                symbol: trade.symbol,
                targetAccountId: trade.targetAccountId,
                action: trade.action,
                quantity: scaledQty,
                estimatedPrice: trade.estimatedPrice
            )
        }
    }

    /// After integer rounding we may have leftover cash that would otherwise sit idle.
    /// Greedily add shares (cheapest eligible first) until no single buy fits.
    /// Never spends more than available cash; never produces a buy that exceeds cash.
    private static func distributeLeftoverCash(
        _ trades: [TradeInstruction],
        availableCash: Double,
        mode: RebalanceMode
    ) -> [TradeInstruction] {
        // Only redistribute against cash we actually have this pass. In `.fullRebalance`
        // we conservatively ignore proceeds from sells (brokers don't settle immediately).
        let buyCost = trades.filter { $0.action == .buy }.reduce(0) { $0 + $1.estimatedCost }
        var leftover = availableCash - buyCost
        guard leftover > 0 else { return trades }

        var result = trades
        // Safety bound — prevent runaway loops on malformed input.
        let maxIterations = 10_000
        var iterations = 0
        while iterations < maxIterations {
            iterations += 1
            // Pick the cheapest buy we can still afford.
            guard let idx = result.enumerated()
                    .filter({ $0.element.action == .buy && $0.element.estimatedPrice > 0 && $0.element.estimatedPrice <= leftover })
                    .min(by: { $0.element.estimatedPrice < $1.element.estimatedPrice })?.offset
            else { break }
            let t = result[idx]
            let newQty = t.quantity + 1
            result[idx] = TradeInstruction(
                securityId: t.securityId,
                symbol: t.symbol,
                targetAccountId: t.targetAccountId,
                action: t.action,
                quantity: newQty,
                estimatedPrice: t.estimatedPrice
            )
            leftover -= t.estimatedPrice
            _ = mode  // reserved for future mode-specific behavior
        }
        return result
    }
}
