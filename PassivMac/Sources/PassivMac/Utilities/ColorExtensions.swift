import SwiftUI

extension Color {
    static let gain     = Color.green
    static let loss     = Color.red
    static let neutral  = Color.secondary

    /// Green for gain, red for loss, secondary for zero
    static func pnl(_ value: Double) -> Color {
        if value > 0 { return .gain }
        if value < 0 { return .loss }
        return .neutral
    }

    /// Green when accuracy is high, yellow when mid, red when low
    static func accuracy(_ fraction: Double) -> Color {
        switch fraction {
        case 0.95...: return .green
        case 0.85...: return .yellow
        default:      return .red
        }
    }
}
