import Foundation
import SwiftData

/// BrokerageProvider adapter for Questrade.
/// Full read + trade support via the official Questrade REST API.
///
/// Questrade API docs: https://www.questrade.com/api/documentation/rest-operations
actor QuestradeProvider: BrokerageProvider {

    let type: BrokerageType = .questrade

    private let http = HTTPClient()
    private let rateLimiter = RateLimiter()
    private let keychain = KeychainService.shared

    // MARK: - Token Management

    func refreshTokenIfNeeded(connectionId: UUID, expiresAt: Date?) async throws {
        let buffer: TimeInterval = 60  // refresh 60s before expiry
        guard let expiresAt, Date().addingTimeInterval(buffer) >= expiresAt else { return }
        try await performTokenRefresh(connectionId: connectionId)
    }

    private func performTokenRefresh(connectionId: UUID) async throws {
        let refreshToken = try await keychain.retrieve(for: .refreshToken(connectionId: connectionId))
        let params = QuestradeEndpoints.tokenRefreshParams(refreshToken: refreshToken)
        let response: QuestradeTokenResponse = try await http.postForm(
            QuestradeEndpoints.tokenURL(),
            formParams: params
        )
        try await keychain.store(response.accessToken, for: .accessToken(connectionId: connectionId))
        try await keychain.store(response.refreshToken, for: .refreshToken(connectionId: connectionId))
        // Caller is responsible for updating tokenExpiresAt on BrokerageConnection in SwiftData.
    }

    // MARK: - Accounts

    func fetchAccounts(connectionId: UUID) async throws -> [RemoteAccount] {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)
        let response: QuestradeAccountsResponse = try await http.get(
            QuestradeEndpoints.accounts(apiServer: apiServer),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        return response.accounts.map { account in
            RemoteAccount(
                brokerageAccountId: account.number,
                displayName: "\(account.type) (\(account.number))",
                accountType: mapAccountType(account.type),
                currency: .cad   // Questrade accounts are CAD or USD; Questrade API returns per-currency balances
            )
        }
    }

    // MARK: - Positions

    func fetchPositions(accountId: String, connectionId: UUID) async throws -> [RemotePosition] {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)
        let response: QuestradePositionsResponse = try await http.get(
            QuestradeEndpoints.positions(apiServer: apiServer, accountNumber: accountId),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        return response.positions.map { p in
            RemotePosition(
                symbol: p.symbol,
                openQuantity: p.openQuantity,
                averageCost: p.averageEntryPrice,
                currentPrice: p.currentPrice,
                currentValue: p.currentMarketValue,
                openPnl: p.openPnl,
                dayPnl: 0,      // not in position response; comes from quotes
                currency: .cad  // positions use account currency; resolved when creating Balance
            )
        }
    }

    // MARK: - Balances

    func fetchBalances(accountId: String, connectionId: UUID) async throws -> [RemoteBalance] {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)
        let response: QuestradeBalancesResponse = try await http.get(
            QuestradeEndpoints.balances(apiServer: apiServer, accountNumber: accountId),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        return response.perCurrencyBalances.map { b in
            RemoteBalance(
                currency: Currency(rawValue: b.currency) ?? .cad,
                cash: b.cash,
                marketValue: b.marketValue
            )
        }
    }

    // MARK: - Activities

    func fetchActivities(accountId: String, from: Date, connectionId: UUID) async throws -> [RemoteActivity] {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)
        let response: QuestradeActivitiesResponse = try await http.get(
            QuestradeEndpoints.activities(
                apiServer: apiServer,
                accountNumber: accountId,
                startTime: from,
                endTime: Date()
            ),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        let parser = ISO8601DateFormatter()
        return response.activities.compactMap { a in
            guard let date = parser.date(from: a.settlementDate) else { return nil }
            return RemoteActivity(
                type: mapActivityType(a.action),
                symbol: a.symbol.isEmpty ? nil : a.symbol,
                amount: a.netAmount,
                currency: Currency(rawValue: a.currency) ?? .cad,
                settledAt: date
            )
        }
    }

    // MARK: - Orders

    func placeOrder(_ order: OrderRequest, connectionId: UUID) async throws -> RemoteOrder {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)

        // Questrade requires symbolId — look it up first
        let symbolResult = try await searchSymbols(query: order.symbol, connectionId: connectionId)
        guard let match = symbolResult.first(where: { $0.symbol == order.symbol }) else {
            throw APIError.brokerageError("Symbol \(order.symbol) not found on Questrade")
        }
        guard let symbolId = Int(match.id) else {
            throw APIError.brokerageError("Invalid symbolId for \(order.symbol)")
        }

        let body = QuestradeOrderRequest(
            accountNumber: order.accountId,
            symbolId: symbolId,
            quantity: Int(order.quantity),
            icebergQuantity: nil,
            limitPrice: order.orderType == .limit ? order.limitPrice : nil,
            stopPrice: nil,
            isAllOrNone: false,
            isAnonymous: false,
            action: order.action == .buy ? "Buy" : "Sell",
            orderType: order.orderType == .market ? "Market" : "Limit",
            timeInForce: "Day",
            primaryRoute: "AUTO",
            secondaryRoute: "AUTO"
        )

        let response: QuestradeOrderResponse = try await http.post(
            QuestradeEndpoints.orders(apiServer: apiServer, accountNumber: order.accountId),
            body: body,
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        guard let qtOrder = response.orders.first else {
            throw APIError.brokerageError("No order returned from Questrade")
        }
        return RemoteOrder(
            brokerageOrderId: String(qtOrder.id),
            status: mapOrderState(qtOrder.state),
            filledQuantity: qtOrder.filledQuantity,
            filledPrice: qtOrder.avgExecPrice ?? 0
        )
    }

    func cancelOrder(brokerageOrderId: String, accountId: String, connectionId: UUID) async throws {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        guard let orderId = Int(brokerageOrderId) else {
            throw APIError.brokerageError("Invalid order ID: \(brokerageOrderId)")
        }
        await rateLimiter.throttle(for: .questrade)
        try await http.delete(
            QuestradeEndpoints.order(apiServer: apiServer, accountNumber: accountId, orderId: orderId),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
    }

    // MARK: - Symbol Search

    func searchSymbols(query: String, connectionId: UUID) async throws -> [SymbolSearchResult] {
        let (token, apiServer) = try await credentials(connectionId: connectionId)
        await rateLimiter.throttle(for: .questrade)
        let response: QuestradeSymbolSearchResponse = try await http.get(
            QuestradeEndpoints.symbolSearch(apiServer: apiServer, prefix: query),
            headers: QuestradeEndpoints.authHeader(accessToken: token)
        )
        return response.symbols.filter { $0.isTradable }.map { s in
            SymbolSearchResult(
                id: String(s.symbolId),
                symbol: s.symbol,
                name: s.description,
                exchange: s.listingExchange,
                currency: Currency(rawValue: s.currency) ?? .cad,
                assetType: mapSecurityType(s.securityType)
            )
        }
    }

    // MARK: - Private helpers

    private func credentials(connectionId: UUID) async throws -> (accessToken: String, apiServer: String) {
        let token = try await keychain.retrieve(for: .accessToken(connectionId: connectionId))
        // apiServer is stored in SwiftData BrokerageConnection.apiServer — caller must pass it.
        // For now, we read it from UserDefaults keyed by connectionId as a lightweight cache.
        let key = "qs_apiServer_\(connectionId.uuidString)"
        let apiServer = UserDefaults.standard.string(forKey: key) ?? "https://api01.iq.questrade.com/"
        return (token, apiServer)
    }

    private func mapAccountType(_ type: String) -> AccountType {
        switch type.uppercased() {
        case "TFSA":   return .tfsa
        case "RRSP":   return .rrsp
        case "FHSA":   return .fhsa
        case "RRIF":   return .rrif
        case "MARGIN": return .margin
        default:       return .nonRegistered
        }
    }

    private func mapActivityType(_ action: String) -> RemoteActivity.ActivityType {
        switch action.uppercased() {
        case "DEP":  return .deposit
        case "WDR":  return .withdrawal
        case "DIV":  return .dividend
        case "BUY":  return .buy
        case "SELL": return .sell
        default:     return .other
        }
    }

    private func mapOrderState(_ state: String) -> TradeStatus {
        switch state.lowercased() {
        case "filled":    return .filled
        case "cancelled": return .cancelled
        case "failed":    return .failed
        default:          return .submitted
        }
    }

    private func mapSecurityType(_ type: String) -> AssetType {
        switch type.lowercased() {
        case "mutualfund": return .mutualFund
        case "bond":       return .bond
        default:           return type.lowercased() == "etf" ? .etf : .stock
        }
    }
}
