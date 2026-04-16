import Foundation

enum TradeAction: String, Codable {
    case buy  = "Buy"
    case sell = "Sell"
}

enum TradeStatus: String, Codable {
    case pending   = "Pending"
    case submitted = "Submitted"
    case filled    = "Filled"
    case failed    = "Failed"
    case cancelled = "Cancelled"
}

enum OrderType: String, Codable, CaseIterable, Identifiable {
    case market = "Market"
    case limit  = "Limit"

    var id: String { rawValue }
}

enum RebalanceMode: String, Codable, CaseIterable, Identifiable {
    case buyOnly       = "Buy Only"       // allocate available cash, never sell
    case fullRebalance = "Full Rebalance" // buy underweight + sell overweight

    var id: String { rawValue }
}

enum AllocationMode: String, Codable {
    case percent    = "Percent"
    case fixedDollar = "FixedDollar"
}
