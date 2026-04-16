import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case cad = "CAD"
    case usd = "USD"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .cad: return "C$"
        case .usd: return "US$"
        }
    }

    var locale: Locale {
        switch self {
        case .cad: return Locale(identifier: "en_CA")
        case .usd: return Locale(identifier: "en_US")
        }
    }
}
