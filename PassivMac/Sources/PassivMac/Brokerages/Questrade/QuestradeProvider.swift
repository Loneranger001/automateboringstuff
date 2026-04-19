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

    /// Per-connection in-flight refresh tasks. Coalesces concurrent refresh attempts
    /// so two sync loops can't both hit /oauth2/token simultaneously and corrupt state.
    private var inflightRefreshes: [UUID: Task<Void, Error>] = [:]

    /// In-memory cache of the current access token per connection.
    /// Avoids repeat `keychain.get()` calls — on ad-hoc-signed builds the macOS
    /// Keychain prompts for the login password on every read because the ACL
    /// can't trust an unstable signing identity. Cache is invalidated on refresh.
    private var accessTokenCache: [UUID: String] = [:]

    // MARK: - Rate-limit-aware HTTP wrappers

    /// Throttles, calls the underlying HTTPClient, records 429s into the rate limiter.
    private func rlGet<T: Decodable>(_ url: URL, headers: [String: String]) async throws -> T {
        await rateLimiter.throttle(for: .questrade)
        do {
            let r: T = try await http.get(url, headers: headers)
            await rateLimiter.recordSuccess(for: .questrade)
            return r
        } catch APIError.rateLimited(let retry) {
            await rateLimiter.recordRateLimit(for: .questrade, retryAfter: retry)
            throw APIError.rateLimited(retryAfter: retry)
        }
    }

    private func rlPost<Body: Encodable, Response: Decodable>(
        _ url: URL, body: Body, headers: [String: String]
    ) async throws -> Response {
        await rateLimiter.throttle(for: .questrade)
        do {
            let r: Response = try await http.post(url, body: body, headers: headers)
            await rateLimiter.recordSuccess(for: .questrade)
            return r
        } catch APIError.rateLimited(let retry) {
            await rateLimiter.recordRateLimit(for: .questrade, retryAfter: retry)
            throw APIError.rateLimited(retryAfter: retry)
        }
    }

    private func rlDelete(_ url: URL, headers: [String: String]) async throws {
        await rateLimiter.throttle(for: .questrade)
        do {
            try await http.delete(url, headers: headers)
            await rateLimiter.recordSuccess(for: .questrade)
        } catch APIError.rateLimited(let retry) {
            await rateLimiter.recordRateLimit(for: .questrade, retryAfter: retry)
            throw APIError.rateLimited(retryAfter: retry)
        }
    }

    // MARK: - Token Management

    func refreshTokenIfNeeded(connectionId: UUID, expiresAt: Date?) async throws {
        let buffer: TimeInterval = 60  // refresh 60s before expiry
        guard let expiresAt, Date().addingTimeInterval(buffer) >= expiresAt else { return }

        // Coalesce: if a refresh for this connectionId is already running, await it.
        if let existing = inflightRefreshes[connectionId] {
            try await existing.value
            return
        }
        let task = Task { [weak self] in
            defer { Task { await self?.clearInflight(connectionId) } }
            try await self?.performTokenRefresh(connectionId: connectionId)
        }
        inflightRefreshes[connectionId] = task
        do {
            try await task.value
        } catch {
            // Clear immediately so the next attempt can try again with a fresh request.
            inflightRefreshes[connectionId] = nil
            throw error
        }
    }

    private func clearInflight(_ connectionId: UUID) {
        inflightRefreshes[connectionId] = nil
    }

    private func performTokenRefresh(connectionId: UUID) async throws {
        let refreshToken = try await keychain.retrieve(for: .refreshToken(connectionId: connectionId))
        let params = QuestradeEndpoints.tokenRefreshParams(refreshToken: refreshToken)
        let response: QuestradeTokenResponse = try await http.postForm(
            try QuestradeEndpoints.tokenURL(),
            formParams: params
        )
        try await keychain.store(response.accessToken, for: .accessToken(connectionId: connectionId))
        try await keychain.store(response.refreshToken, for: .refreshToken(connectionId: connectionId))
        // Update in-memory cache + apiServer so subsequent requests immediately use the new token.
        accessTokenCache[connectionId] = response.accessToken
        UserDefaults.standard.set(response.apiServer, forKey: "qs_apiServer_\(connectionId.uuidString)")
        // Caller is responsible for updating tokenExpiresAt on BrokerageConnection in SwiftData.
    }

    /// Run an API-call closure, and on `authExpired` refresh the token and retry once.
    /// Keeps the fix for the "Authentication expired" error out of every individual
    /// call site — symbol search, trade placement, etc.
    private func withAuthRetry<T>(
        connectionId: UUID,
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch APIError.authExpired {
            try await performTokenRefresh(connectionId: connectionId)
            return try await operation()
        }
    }

    // MARK: - Accounts

    func fetchAccounts(connectionId: UUID) async throws -> [RemoteAccount] {
        let response: QuestradeAccountsResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlGet(
                try QuestradeEndpoints.accounts(apiServer: apiServer),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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
        let response: QuestradePositionsResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlGet(
                try QuestradeEndpoints.positions(apiServer: apiServer, accountNumber: accountId),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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
        let response: QuestradeBalancesResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlGet(
                try QuestradeEndpoints.balances(apiServer: apiServer, accountNumber: accountId),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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
        let response: QuestradeActivitiesResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlGet(
                try QuestradeEndpoints.activities(
                    apiServer: apiServer,
                    accountNumber: accountId,
                    startTime: from,
                    endTime: Date()
                ),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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

        let response: QuestradeOrderResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlPost(
                try QuestradeEndpoints.orders(apiServer: apiServer, accountNumber: order.accountId),
                body: body,
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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
        guard let orderId = Int(brokerageOrderId) else {
            throw APIError.brokerageError("Invalid order ID: \(brokerageOrderId)")
        }
        try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            try await rlDelete(
                try QuestradeEndpoints.order(apiServer: apiServer, accountNumber: accountId, orderId: orderId),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
    }

    // MARK: - Symbol Search

    func searchSymbols(query: String, connectionId: UUID) async throws -> [SymbolSearchResult] {
        let response: QuestradeSymbolSearchResponse = try await withAuthRetry(connectionId: connectionId) {
            let (token, apiServer) = try await credentials(connectionId: connectionId)
            return try await rlGet(
                try QuestradeEndpoints.symbolSearch(apiServer: apiServer, prefix: query),
                headers: QuestradeEndpoints.authHeader(accessToken: token)
            )
        }
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
        let token: String
        if let cached = accessTokenCache[connectionId] {
            token = cached
        } else {
            token = try await keychain.retrieve(for: .accessToken(connectionId: connectionId))
            accessTokenCache[connectionId] = token
        }
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
