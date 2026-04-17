import Foundation
import SwiftData

/// One data point in the portfolio's value history. Recorded on every sync.
/// Used for performance charting and TWR calculation.
@Model
final class PortfolioSnapshot {
    var id: UUID
    var portfolioGroupId: UUID
    var totalValue: Double          // total market value + cash, in base currency
    var totalCash: Double           // cash across all accounts, in base currency
    var netContributions: Double    // cumulative net contributions at this point
    var baseCurrencyRaw: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        portfolioGroupId: UUID,
        totalValue: Double,
        totalCash: Double,
        netContributions: Double,
        baseCurrency: Currency = .cad
    ) {
        self.id = id
        self.portfolioGroupId = portfolioGroupId
        self.totalValue = totalValue
        self.totalCash = totalCash
        self.netContributions = netContributions
        self.baseCurrencyRaw = baseCurrency.rawValue
        self.recordedAt = Date()
    }

    var baseCurrency: Currency {
        get { Currency(rawValue: baseCurrencyRaw) ?? .cad }
        set { baseCurrencyRaw = newValue.rawValue }
    }
}
