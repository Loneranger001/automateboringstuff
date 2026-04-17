import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case tfsa            = "TFSA"
    case rrsp            = "RRSP"
    case fhsa            = "FHSA"
    case rrif            = "RRIF"
    case nonRegistered   = "Non-Registered"
    case margin          = "Margin"
    case crypto          = "Crypto"
    case other           = "Other"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Whether this is a registered (tax-advantaged) Canadian account type
    var isRegistered: Bool {
        switch self {
        case .tfsa, .rrsp, .fhsa, .rrif: return true
        default: return false
        }
    }
}
