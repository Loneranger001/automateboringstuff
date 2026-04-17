import Foundation

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case etf         = "ETF"
    case stock       = "Stock"
    case mutualFund  = "MutualFund"
    case bond        = "Bond"
    case crypto      = "Crypto"
    case cash        = "Cash"
    case other       = "Other"

    var id: String { rawValue }
    var displayName: String { rawValue }
}
