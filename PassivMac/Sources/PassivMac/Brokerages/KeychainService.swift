import Foundation
import KeychainAccess

/// Typed Keychain keys for brokerage OAuth tokens.
enum KeychainKey {
    case accessToken(connectionId: UUID)
    case refreshToken(connectionId: UUID)
    case apiKey(connectionId: UUID)       // For API-key auth (e.g. Alpaca)
    case apiSecret(connectionId: UUID)

    var rawValue: String {
        switch self {
        case .accessToken(let id):  return "access_\(id.uuidString)"
        case .refreshToken(let id): return "refresh_\(id.uuidString)"
        case .apiKey(let id):       return "apikey_\(id.uuidString)"
        case .apiSecret(let id):    return "apisecret_\(id.uuidString)"
        }
    }
}

/// Stores and retrieves brokerage OAuth tokens from the macOS Keychain.
/// Tokens NEVER touch SwiftData or UserDefaults.
actor KeychainService {

    static let shared = KeychainService()

    private let keychain = Keychain(service: "com.passivmac.tokens")
        .accessibility(.afterFirstUnlockThisDeviceOnly)

    private init() {}

    func store(_ token: String, for key: KeychainKey) throws {
        try keychain.set(token, key: key.rawValue)
    }

    func retrieve(for key: KeychainKey) throws -> String {
        guard let value = try keychain.get(key.rawValue) else {
            throw KeychainError.notFound(key.rawValue)
        }
        return value
    }

    func delete(for key: KeychainKey) throws {
        try keychain.remove(key.rawValue)
    }

    func deleteAll(for connectionId: UUID) {
        let keys: [KeychainKey] = [
            .accessToken(connectionId: connectionId),
            .refreshToken(connectionId: connectionId),
            .apiKey(connectionId: connectionId),
            .apiSecret(connectionId: connectionId),
        ]
        for key in keys {
            try? keychain.remove(key.rawValue)
        }
    }
}

enum KeychainError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let key):
            return "Keychain item not found for key: \(key)"
        }
    }
}
