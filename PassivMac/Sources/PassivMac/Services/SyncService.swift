import Foundation
import SwiftData

/// Orchestrates syncing all connected brokerage accounts into SwiftData.
/// Call `syncAll()` to refresh everything, or `sync(connection:)` for one brokerage.
@MainActor
final class SyncService {

    static let shared = SyncService()

    private let providers: [BrokerageType: any BrokerageProvider] = [
        .questrade: QuestradeProvider(),
        .ibkr:      IBKRProvider(),
    ]

    private init() {}

    // MARK: - Public

    var isSyncing = false
    var lastError: Error?

    /// Sync all active connections in the model context.
    func syncAll(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let connections = (try? context.fetch(FetchDescriptor<BrokerageConnection>(
            predicate: #Predicate { $0.isActive }
        ))) ?? []

        for connection in connections {
            do {
                try await sync(connection: connection, context: context)
            } catch {
                lastError = error
            }
        }
    }

    /// Sync a single BrokerageConnection: refresh tokens, fetch accounts, positions, balances.
    func sync(connection: BrokerageConnection, context: ModelContext) async throws {
        guard let provider = providers[connection.brokerageType] else { return }

        try await provider.refreshTokenIfNeeded(
            connectionId: connection.id,
            expiresAt: connection.tokenExpiresAt
        )

        let remoteAccounts = try await provider.fetchAccounts(connectionId: connection.id)

        for remoteAccount in remoteAccounts {
            let account = upsertAccount(remoteAccount, connection: connection, context: context)
            try await syncPositions(account: account, provider: provider, connectionId: connection.id, context: context)
            try await syncBalances(account: account, provider: provider, connectionId: connection.id, context: context)
        }

        // Record snapshots for any portfolio groups that contain these accounts
        let groups = (try? context.fetch(FetchDescriptor<PortfolioGroup>())) ?? []
        for group in groups {
            recordSnapshot(for: group, context: context)
        }

        connection.lastSyncedAt = Date()
        try context.save()
    }

    // MARK: - Private: Account

    private func upsertAccount(
        _ remote: RemoteAccount,
        connection: BrokerageConnection,
        context: ModelContext
    ) -> Account {
        let existing = connection.accounts.first(where: { $0.brokerageAccountId == remote.brokerageAccountId })
        if let existing { return existing }

        let account = Account(
            brokerageAccountId: remote.brokerageAccountId,
            displayName: remote.displayName,
            accountType: remote.accountType,
            currency: remote.currency,
            connection: connection
        )
        context.insert(account)
        connection.accounts.append(account)
        return account
    }

    // MARK: - Private: Positions

    private func syncPositions(
        account: Account,
        provider: any BrokerageProvider,
        connectionId: UUID,
        context: ModelContext
    ) async throws {
        let remotePositions = try await provider.fetchPositions(
            accountId: account.brokerageAccountId,
            connectionId: connectionId
        )

        // Delete all stale positions for this account and replace with fresh data
        for old in account.positions { context.delete(old) }
        account.positions = []

        for rp in remotePositions where rp.openQuantity > 0 {
            let security = upsertSecurity(symbol: rp.symbol, currency: rp.currency, context: context)
            let position = Position(
                account: account,
                security: security,
                symbol: rp.symbol,
                openQuantity: rp.openQuantity,
                averageCost: rp.averageCost,
                currentPrice: rp.currentPrice,
                currency: rp.currency
            )
            position.currentValue = rp.currentValue
            position.openPnl = rp.openPnl
            context.insert(position)
            account.positions.append(position)
            security.lastPrice = rp.currentPrice
            security.lastPriceFetchedAt = Date()
        }
    }

    // MARK: - Private: Balances

    private func syncBalances(
        account: Account,
        provider: any BrokerageProvider,
        connectionId: UUID,
        context: ModelContext
    ) async throws {
        let remoteBalances = try await provider.fetchBalances(
            accountId: account.brokerageAccountId,
            connectionId: connectionId
        )

        for old in account.balances { context.delete(old) }
        account.balances = []

        for rb in remoteBalances {
            let balance = Balance(
                account: account,
                currency: rb.currency,
                cash: rb.cash,
                marketValue: rb.marketValue
            )
            context.insert(balance)
            account.balances.append(balance)
        }
    }

    // MARK: - Private: Security upsert

    private func upsertSecurity(symbol: String, currency: Currency, context: ModelContext) -> Security {
        let existing = try? context.fetch(
            FetchDescriptor<Security>(predicate: #Predicate { $0.symbol == symbol })
        ).first
        if let existing { return existing }

        let security = Security(symbol: symbol, name: symbol, currency: currency)
        context.insert(security)
        return security
    }

    // MARK: - Private: Portfolio snapshot

    private func recordSnapshot(for group: PortfolioGroup, context: ModelContext) {
        let fxService = FXRateService.shared
        var totalValue = 0.0
        var totalCash = 0.0

        for account in group.accounts {
            // TODO (Phase 2): convert to base currency using FXRateService for USD accounts
            totalValue += account.totalMarketValue + account.cashBalance
            totalCash  += account.cashBalance
        }

        // Avoid duplicate snapshots within 1 hour
        if let last = group.snapshots.last,
           Date().timeIntervalSince(last.recordedAt) < 3600 {
            last.totalValue = totalValue
            last.totalCash = totalCash
            return
        }

        let netContributions = group.snapshots.last?.netContributions ?? totalValue
        let snapshot = PortfolioSnapshot(
            portfolioGroupId: group.id,
            totalValue: totalValue,
            totalCash: totalCash,
            netContributions: netContributions,
            baseCurrency: group.baseCurrency
        )
        context.insert(snapshot)
        group.snapshots.append(snapshot)
        _ = fxService  // suppress unused warning until Phase 2
    }
}
