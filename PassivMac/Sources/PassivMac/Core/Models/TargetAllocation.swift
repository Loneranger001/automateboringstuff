import Foundation
import SwiftData

@Model
final class TargetAllocation {
    var id: UUID
    var portfolioGroup: PortfolioGroup?
    var security: Security?
    /// Symbol kept denormalized so the editor works even if security is nil
    var symbol: String
    /// Target weight as a fraction (0.0–1.0). Used when allocationMode == .percent
    var targetPercent: Double
    /// Target fixed dollar amount. Used when allocationMode == .fixedDollar
    var targetFixedDollar: Double
    var allocationModeRaw: String   // AllocationMode raw value
    /// When true, this security is excluded from rebalance calculations
    var excludeFromRebalance: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        portfolioGroup: PortfolioGroup? = nil,
        security: Security? = nil,
        symbol: String,
        targetPercent: Double = 0,
        allocationMode: AllocationMode = .percent
    ) {
        self.id = id
        self.portfolioGroup = portfolioGroup
        self.security = security
        self.symbol = symbol
        self.targetPercent = targetPercent
        self.targetFixedDollar = 0
        self.allocationModeRaw = allocationMode.rawValue
        self.excludeFromRebalance = false
        self.createdAt = Date()
    }

    var allocationMode: AllocationMode {
        get { AllocationMode(rawValue: allocationModeRaw) ?? .percent }
        set { allocationModeRaw = newValue.rawValue }
    }

    /// Human-readable target label (e.g. "40%" or "$5,000")
    var targetLabel: String {
        switch allocationMode {
        case .percent:
            return String(format: "%.1f%%", targetPercent * 100)
        case .fixedDollar:
            return FormatUtils.currency(targetFixedDollar, currency: .cad)
        }
    }
}
