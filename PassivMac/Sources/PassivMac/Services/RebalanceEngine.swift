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

        guard totalPortfolioValue > 0 else { return [] }

        // Target value for each allocation
        var deltas: [(securityId: UUID, symbol: String, delta: Double, price: Double)] = []

        for allocation in input.targetAllocations {
            guard let price = input.currentPrices[allocation.securityId], price > 0 else { continue }
            guard input.accountAssignments[allocation.securityId] != nil else { continue }

            let targetValue = allocation.targetPercent * totalPortfolioValue
            let currentValue = input.currentHoldings.first(where: { $0.securityId == allocation.securityId })?.currentValue ?? 0
            let delta = targetValue - currentValue

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
            trades = scaleBuysToAvailableCash(trades, availableCash: input.availableCash)
        }

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
}
