import Foundation

// MARK: - OAuth

struct QuestradeTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int           // seconds until expiry
    let refreshToken: String
    let apiServer: String        // e.g. "https://api01.iq.questrade.com/"
}

// MARK: - Accounts

struct QuestradeAccountsResponse: Decodable {
    let accounts: [QuestradeAccount]
    let userId: Int
}

struct QuestradeAccount: Decodable {
    let type: String             // "TFSA", "RRSP", etc.
    let number: String           // account number used in all subsequent API calls
    let status: String           // "Active"
    let isPrimary: Bool
    let isBilling: Bool
    let clientAccountType: String
}

// MARK: - Positions

struct QuestradePositionsResponse: Decodable {
    let positions: [QuestradePosition]
}

struct QuestradePosition: Decodable {
    let symbol: String
    let symbolId: Int
    let openQuantity: Double
    let closedQuantity: Double
    let currentMarketValue: Double
    let currentPrice: Double
    let averageEntryPrice: Double
    let closedPnl: Double
    let openPnl: Double
    let totalCost: Double
    let isRealTime: Bool
    let isUnderReorg: Bool
}

// MARK: - Balances

struct QuestradeBalancesResponse: Decodable {
    let perCurrencyBalances: [QuestradeBalance]
    let combinedBalances: [QuestradeBalance]
    let sodPerCurrencyBalances: [QuestradeBalance]
    let sodCombinedBalances: [QuestradeBalance]
}

struct QuestradeBalance: Decodable {
    let currency: String
    let cash: Double
    let marketValue: Double
    let totalEquity: Double
    let buyingPower: Double
    let maintenanceExcess: Double
    let isRealTime: Bool
}

// MARK: - Activities

struct QuestradeActivitiesResponse: Decodable {
    let activities: [QuestradeActivity]
}

struct QuestradeActivity: Decodable {
    let tradeDate: String
    let transactionDate: String
    let settlementDate: String
    let action: String           // "Buy", "Sell", "Div", "DEP", "WDR", etc.
    let symbol: String
    let symbolId: Int
    let description: String
    let currency: String
    let quantity: Double
    let price: Double
    let grossAmount: Double
    let commission: Double
    let netAmount: Double
    let type: String
}

// MARK: - Orders

struct QuestradeOrderRequest: Encodable {
    let accountNumber: String
    let symbolId: Int
    let quantity: Int
    let icebergQuantity: Int?
    let limitPrice: Double?
    let stopPrice: Double?
    let isAllOrNone: Bool
    let isAnonymous: Bool
    let action: String           // "Buy" or "Sell"
    let orderType: String        // "Market" or "Limit"
    let timeInForce: String      // "Day" or "GoodTillCanceled"
    let primaryRoute: String
    let secondaryRoute: String
}

struct QuestradeOrderResponse: Decodable {
    let orders: [QuestradeOrder]
}

struct QuestradeOrder: Decodable {
    let id: Int
    let symbol: String
    let symbolId: Int
    let totalQuantity: Double
    let openQuantity: Double
    let filledQuantity: Double
    let cancelledQuantity: Double
    let side: String
    let orderType: String
    let limitPrice: Double?
    let stopPrice: Double?
    let isAllOrNone: Bool
    let isAnonymous: Bool
    let timeInForce: String
    let gtdDate: String?
    let state: String            // "Queued", "Accepted", "Filled", "Cancelled", "Failed"
    let rejectionReason: String?
    let avgExecPrice: Double?
    let lastExecPrice: Double?
    let source: String
    let isSignificantShareholder: Bool
    let isInsider: Bool
    let isLimitOffsetInDollar: Bool
    let userId: Int
    let placedTime: String
    let updatedTime: String
}

// MARK: - Symbol Search

struct QuestradeSymbolSearchResponse: Decodable {
    let symbols: [QuestradeSymbol]
}

struct QuestradeSymbol: Decodable {
    let symbol: String
    let symbolId: Int
    let description: String
    let securityType: String     // "Stock", "Option", "Bond", "Right", "Gold", "MutualFund", "Index"
    let listingExchange: String
    let isQuotable: Bool
    let isTradable: Bool
    let currency: String
}
