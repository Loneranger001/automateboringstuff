import Foundation
import SwiftData

/// A single trade instruction produced by RebalanceEngine.
/// Regenerated on every rebalance calculation — not a permanent record.
@Model
final class CalculatedTrade {
    var id: UUID
    var portfolioGroupId: UUID
    var targetAccountId: UUID
    var securityId: UUID
    var symbol: String
    var actionRaw: String      // TradeAction raw value
    var quantity: Double
    var estimatedPrice: Double
    var estimatedCost: Double
    var currencyRaw: String
    var fxRateUsed: Double     // FX rate at calculation time (1.0 if same currency)
    var statusRaw: String      // TradeStatus raw value
    var calculatedAt: Date
    /// Whether the user has manually excluded this trade from the batch
    var isExcluded: Bool

    init(
        id: UUID = UUID(),
        portfolioGroupId: UUID,
        targetAccountId: UUID,
        securityId: UUID,
        symbol: String,
        action: TradeAction,
        quantity: Double,
        estimatedPrice: Double,
        estimatedCost: Double,
        currency: Currency,
        fxRateUsed: Double = 1.0
    ) {
        self.id = id
        self.portfolioGroupId = portfolioGroupId
        self.targetAccountId = targetAccountId
        self.securityId = securityId
        self.symbol = symbol
        self.actionRaw = action.rawValue
        self.quantity = quantity
        self.estimatedPrice = estimatedPrice
        self.estimatedCost = estimatedCost
        self.currencyRaw = currency.rawValue
        self.fxRateUsed = fxRateUsed
        self.statusRaw = TradeStatus.pending.rawValue
        self.calculatedAt = Date()
        self.isExcluded = false
    }

    var action: TradeAction {
        get { TradeAction(rawValue: actionRaw) ?? .buy }
        set { actionRaw = newValue.rawValue }
    }

    var status: TradeStatus {
        get { TradeStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }
}
