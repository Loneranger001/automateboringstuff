import Foundation
import SwiftData

@Model
final class Security {
    var id: UUID
    var symbol: String
    var name: String
    var exchange: String
    var currencyRaw: String    // Currency raw value
    var assetTypeRaw: String   // AssetType raw value
    /// Cached last trade price — refreshed on every sync
    var lastPrice: Double
    var lastPriceFetchedAt: Date?

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        exchange: String = "",
        currency: Currency = .cad,
        assetType: AssetType = .etf
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.currencyRaw = currency.rawValue
        self.assetTypeRaw = assetType.rawValue
        self.lastPrice = 0
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }

    var assetType: AssetType {
        get { AssetType(rawValue: assetTypeRaw) ?? .etf }
        set { assetTypeRaw = newValue.rawValue }
    }
}
