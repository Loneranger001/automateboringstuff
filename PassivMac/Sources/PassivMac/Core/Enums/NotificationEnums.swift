import Foundation

enum NotificationType: String, Codable, CaseIterable, Identifiable {
    case cashAvailable   = "CashAvailable"   // new cash / dividend hit account
    case driftExceeded   = "DriftExceeded"   // portfolio accuracy dropped below threshold
    case orderFilled     = "OrderFilled"     // placed order was filled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cashAvailable: return "Cash Available"
        case .driftExceeded: return "Portfolio Drift"
        case .orderFilled:   return "Order Filled"
        }
    }

    var defaultThreshold: Double? {
        switch self {
        case .cashAvailable: return 100.0   // dollars
        case .driftExceeded: return 0.05    // 5 % drift
        case .orderFilled:   return nil
        }
    }
}
