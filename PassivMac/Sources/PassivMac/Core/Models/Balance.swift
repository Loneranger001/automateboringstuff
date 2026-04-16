import Foundation
import SwiftData

/// Cash and equity balance for one currency in an account.
/// Deleted and re-created on every sync.
@Model
final class Balance {
    var id: UUID
    var account: Account?
    var currencyRaw: String
    var cash: Double
    var marketValue: Double
    var totalEquity: Double    // cash + marketValue
    var syncedAt: Date

    init(
        id: UUID = UUID(),
        account: Account? = nil,
        currency: Currency,
        cash: Double,
        marketValue: Double
    ) {
        self.id = id
        self.account = account
        self.currencyRaw = currency.rawValue
        self.cash = cash
        self.marketValue = marketValue
        self.totalEquity = cash + marketValue
        self.syncedAt = Date()
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }
}
