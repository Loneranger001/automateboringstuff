import Foundation
import SwiftData

/// A holding in a specific account at the time of last sync.
/// Deleted and re-created on every sync (the brokerage is the source of truth).
@Model
final class Position {
    var id: UUID
    var account: Account?
    var security: Security?
    /// Symbol kept denormalized for display performance
    var symbol: String
    var openQuantity: Double
    var averageCost: Double       // per share, in account currency
    var currentPrice: Double      // per share, in account currency
    var currentValue: Double      // openQuantity * currentPrice
    var openPnl: Double           // unrealized P&L
    var dayPnl: Double            // today's P&L
    var currencyRaw: String
    var syncedAt: Date

    init(
        id: UUID = UUID(),
        account: Account? = nil,
        security: Security? = nil,
        symbol: String,
        openQuantity: Double,
        averageCost: Double,
        currentPrice: Double,
        currency: Currency = .cad
    ) {
        self.id = id
        self.account = account
        self.security = security
        self.symbol = symbol
        self.openQuantity = openQuantity
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.currentValue = openQuantity * currentPrice
        self.openPnl = (currentPrice - averageCost) * openQuantity
        self.dayPnl = 0
        self.currencyRaw = currency.rawValue
        self.syncedAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }
}
