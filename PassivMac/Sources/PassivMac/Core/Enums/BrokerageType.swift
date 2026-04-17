import Foundation

enum BrokerageType: String, Codable, CaseIterable, Identifiable {
    case questrade  = "questrade"
    case ibkr       = "ibkr"        // Phase 3

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .questrade: return "Questrade"
        case .ibkr:      return "Interactive Brokers"
        }
    }

    var supportsTrading: Bool {
        switch self {
        case .questrade: return true
        case .ibkr:      return true
        }
    }

    /// OAuth / auth flow used by this brokerage
    var authMethod: AuthMethod {
        switch self {
        case .questrade: return .oauth2
        case .ibkr:      return .clientPortal
        }
    }

    enum AuthMethod {
        case oauth2        // ASWebAuthenticationSession
        case clientPortal  // IBKR Client Portal local gateway
    }
}
