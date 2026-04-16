import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    /// The account ID as returned by the brokerage API (e.g. Questrade account number)
    var brokerageAccountId: String
    var displayName: String
    var accountTypeRaw: String   // AccountType raw value
    var currencyRaw: String      // Currency raw value
    var connection: BrokerageConnection?
    var portfolioGroup: PortfolioGroup?
    @Relationship(deleteRule: .cascade, inverse: \Position.account)
    var positions: [Position]
    @Relationship(deleteRule: .cascade, inverse: \Balance.account)
    var balances: [Balance]
    @Relationship(deleteRule: .cascade, inverse: \DividendRecord.account)
    var dividends: [DividendRecord]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        brokerageAccountId: String,
        displayName: String,
        accountType: AccountType = .nonRegistered,
        currency: Currency = .cad,
        connection: BrokerageConnection? = nil
    ) {
        self.id = id
        self.brokerageAccountId = brokerageAccountId
        self.displayName = displayName
        self.accountTypeRaw = accountType.rawValue
        self.currencyRaw = currency.rawValue
        self.connection = connection
        self.positions = []
        self.balances = []
        self.dividends = []
        self.createdAt = Date()
    }

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .nonRegistered }
        set { accountTypeRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }

    /// Total market value of all positions in this account (account's native currency)
    var totalMarketValue: Double {
        positions.reduce(0) { $0 + $1.currentValue }
    }

    /// Available cash (from latest balance record)
    var cashBalance: Double {
        balances.first(where: { Currency(rawValue: $0.currencyRaw) == currency })?.cash ?? 0
    }
}
