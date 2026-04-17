import Foundation

// MARK: - Remote DTOs (shared across adapters)

struct RemoteAccount {
    let brokerageAccountId: String
    let displayName: String
    let accountType: AccountType
    let currency: Currency
}

struct RemotePosition {
    let symbol: String
    let openQuantity: Double
    let averageCost: Double
    let currentPrice: Double
    let currentValue: Double
    let openPnl: Double
    let dayPnl: Double
    let currency: Currency
}

struct RemoteBalance {
    let currency: Currency
    let cash: Double
    let marketValue: Double
}

struct RemoteActivity {
    let type: ActivityType
    let symbol: String?
    let amount: Double
    let currency: Currency
    let settledAt: Date

    enum ActivityType: String {
        case deposit
        case withdrawal
        case dividend
        case buy
        case sell
        case other
    }
}

struct OrderRequest {
    let accountId: String       // brokerage account ID
    let symbol: String
    let action: TradeAction
    let orderType: OrderType
    let quantity: Double
    let limitPrice: Double?     // required for .limit orders
}

struct RemoteOrder {
    let brokerageOrderId: String
    let status: TradeStatus
    let filledQuantity: Double
    let filledPrice: Double
}

struct SymbolSearchResult: Identifiable {
    let id: String              // symbol
    let symbol: String
    let name: String
    let exchange: String
    let currency: Currency
    let assetType: AssetType
}

// MARK: - Protocol

/// All brokerage adapters conform to this protocol.
/// The domain layer never references a concrete adapter.
protocol BrokerageProvider {
    var type: BrokerageType { get }

    /// Fetch all accounts for this connection.
    func fetchAccounts(connectionId: UUID) async throws -> [RemoteAccount]

    /// Fetch current positions for a single account.
    func fetchPositions(accountId: String, connectionId: UUID) async throws -> [RemotePosition]

    /// Fetch current balances for a single account.
    func fetchBalances(accountId: String, connectionId: UUID) async throws -> [RemoteBalance]

    /// Fetch activity (dividends, deposits, withdrawals) since a given date.
    func fetchActivities(accountId: String, from: Date, connectionId: UUID) async throws -> [RemoteActivity]

    /// Place an order. Returns the brokerage order record.
    func placeOrder(_ order: OrderRequest, connectionId: UUID) async throws -> RemoteOrder

    /// Cancel an in-flight order.
    func cancelOrder(brokerageOrderId: String, accountId: String, connectionId: UUID) async throws

    /// Search for securities by symbol prefix.
    func searchSymbols(query: String, connectionId: UUID) async throws -> [SymbolSearchResult]

    /// Refresh the access token if it is about to expire.
    /// Called automatically by SyncService before any API call.
    func refreshTokenIfNeeded(connectionId: UUID, expiresAt: Date?) async throws
}
