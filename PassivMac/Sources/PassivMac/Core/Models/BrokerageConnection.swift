import Foundation
import SwiftData

@Model
final class BrokerageConnection {
    var id: UUID
    var brokerageTypeRaw: String     // BrokerageType raw value
    var displayName: String
    /// Questrade returns a per-account API server after token exchange, e.g. "https://api01.iq.questrade.com/"
    var apiServer: String
    var tokenExpiresAt: Date?
    var isActive: Bool
    var lastSyncedAt: Date?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Account.connection)
    var accounts: [Account]

    // Tokens are NOT stored here — they live in Keychain via KeychainService.
    // See KeychainService.Key.accessToken(connectionId:) and .refreshToken(connectionId:)

    init(id: UUID = UUID(), brokerageType: BrokerageType, displayName: String) {
        self.id = id
        self.brokerageTypeRaw = brokerageType.rawValue
        self.displayName = displayName
        self.apiServer = ""
        self.isActive = true
        self.accounts = []
        self.createdAt = Date()
    }

    var brokerageType: BrokerageType {
        get { BrokerageType(rawValue: brokerageTypeRaw) ?? .questrade }
        set { brokerageTypeRaw = newValue.rawValue }
    }
}
