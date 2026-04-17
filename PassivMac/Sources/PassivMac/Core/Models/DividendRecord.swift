import Foundation
import SwiftData

/// A dividend payment received in an account.
@Model
final class DividendRecord {
    var id: UUID
    var account: Account?
    var security: Security?
    var symbol: String
    var amount: Double
    var currencyRaw: String
    var paidAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        account: Account? = nil,
        security: Security? = nil,
        symbol: String,
        amount: Double,
        currency: Currency,
        paidAt: Date,
        note: String = ""
    ) {
        self.id = id
        self.account = account
        self.security = security
        self.symbol = symbol
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.paidAt = paidAt
        self.note = note
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }
}
