import Foundation

/// Placeholder adapter for Interactive Brokers — Phase 3 of the roadmap.
///
/// IBKR integration uses the Client Portal API (local REST gateway).
///
/// Setup steps (for Phase 3 implementation):
///   1. User downloads and runs the IBKR Client Portal Gateway locally:
///      https://www.interactivebrokers.com/en/trading/ib-api.php
///   2. Gateway runs at https://localhost:5000 (self-signed TLS — URLSession needs .allowsInvalidCertificates)
///   3. User authenticates once via browser: GET /v1/api/iserver/auth/status
///   4. App keeps the session alive with periodic /v1/api/tickle calls
///
/// Key endpoints:
///   - Session status:   GET  /v1/api/iserver/auth/status
///   - Keep-alive:       POST /v1/api/tickle
///   - Accounts:         GET  /v1/api/iserver/accounts
///   - Positions:        GET  /v1/api/portfolio/{accountId}/positions/0
///   - Balances:         GET  /v1/api/portfolio/{accountId}/ledger
///   - Place order:      POST /v1/api/iserver/account/{accountId}/orders
///   - Order status:     GET  /v1/api/iserver/account/orders/{orderId}
///   - Symbol search:    GET  /v1/api/iserver/secdef/search?symbol={query}
///
/// Reference: https://interactivebrokers.github.io/cpwebapi/
actor IBKRProvider: BrokerageProvider {

    let type: BrokerageType = .ibkr

    // TODO (Phase 3): Implement all BrokerageProvider methods.
    // The stubs below allow the project to compile and the UI to list IBKR
    // as a "coming soon" option without crashing.

    func fetchAccounts(connectionId: UUID) async throws -> [RemoteAccount] {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func fetchPositions(accountId: String, connectionId: UUID) async throws -> [RemotePosition] {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func fetchBalances(accountId: String, connectionId: UUID) async throws -> [RemoteBalance] {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func fetchActivities(accountId: String, from: Date, connectionId: UUID) async throws -> [RemoteActivity] {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func placeOrder(_ order: OrderRequest, connectionId: UUID) async throws -> RemoteOrder {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func cancelOrder(brokerageOrderId: String, accountId: String, connectionId: UUID) async throws {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func searchSymbols(query: String, connectionId: UUID) async throws -> [SymbolSearchResult] {
        throw APIError.brokerageError("IBKR integration coming in Phase 3.")
    }

    func refreshTokenIfNeeded(connectionId: UUID, expiresAt: Date?) async throws {
        // IBKR uses session-based auth (tickle), not token refresh.
        // TODO (Phase 3): POST /v1/api/tickle to keep the session alive.
    }
}
