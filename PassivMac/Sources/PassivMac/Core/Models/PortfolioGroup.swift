import Foundation
import SwiftData

@Model
final class PortfolioGroup {
    var id: UUID
    var name: String
    /// Base currency for cross-account calculations and display
    var baseCurrencyRaw: String  // Currency raw value
    /// Portfolio accuracy threshold — send drift notification below this value (0.0–1.0)
    var driftThreshold: Double
    /// Cash notification threshold in base currency (e.g. 500 = notify when $500+ cash)
    var cashNotificationThreshold: Double
    var createdAt: Date
    @Relationship(inverse: \Account.portfolioGroup)
    var accounts: [Account]
    @Relationship(deleteRule: .cascade, inverse: \TargetAllocation.portfolioGroup)
    var targetAllocations: [TargetAllocation]
    // PortfolioSnapshot stores a plain `portfolioGroupId: UUID` (not a model reference),
    // so there's no inverse to wire up here. Snapshots are managed explicitly in code;
    // cascade delete is handled by filtering on portfolioGroupId if the group is removed.
    @Relationship(deleteRule: .cascade)
    var snapshots: [PortfolioSnapshot]

    init(id: UUID = UUID(), name: String, baseCurrency: Currency = .cad) {
        self.id = id
        self.name = name
        self.baseCurrencyRaw = baseCurrency.rawValue
        self.driftThreshold = 0.05   // 5% default
        self.cashNotificationThreshold = 500
        self.accounts = []
        self.targetAllocations = []
        self.snapshots = []
        self.createdAt = Date()
    }

    var baseCurrency: Currency {
        get { Currency(rawValue: baseCurrencyRaw) ?? .cad }
        set { baseCurrencyRaw = newValue.rawValue }
    }

    /// True if any target allocation has been set up
    var hasTargets: Bool { !targetAllocations.isEmpty }
}
