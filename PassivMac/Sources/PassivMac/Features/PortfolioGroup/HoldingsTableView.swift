import SwiftUI

struct HoldingsTableView: View {
    let group: PortfolioGroup

    private var allPositions: [Position] {
        group.accounts.flatMap { $0.positions }
            .sorted { $0.currentValue > $1.currentValue }
    }

    private var totalValue: Double {
        allPositions.reduce(0) { $0 + $1.currentValue }
            + group.accounts.reduce(0) { $0 + $1.cashBalance }
    }

    private var targets: [UUID: Double] {
        Dictionary(uniqueKeysWithValues:
            group.targetAllocations.compactMap { t -> (UUID, Double)? in
                guard let sec = t.security else { return nil }
                return (sec.id, t.targetPercent)
            }
        )
    }

    var body: some View {
        Table(allPositions) {
            TableColumn("Symbol") { pos in
                VStack(alignment: .leading, spacing: 2) {
                    Text(pos.symbol).fontWeight(.medium)
                    Text(pos.security?.name ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            TableColumn("Shares") { pos in
                Text(FormatUtils.shares(pos.openQuantity))
                    .monospacedDigit()
            }
            TableColumn("Price") { pos in
                Text(FormatUtils.currency(pos.currentPrice, currency: pos.currency))
                    .monospacedDigit()
            }
            TableColumn("Value") { pos in
                Text(FormatUtils.currency(pos.currentValue, currency: pos.currency))
                    .monospacedDigit()
                    .fontWeight(.medium)
            }
            TableColumn("Weight") { pos in
                let weight = totalValue > 0 ? pos.currentValue / totalValue : 0
                Text(FormatUtils.percent(weight))
                    .monospacedDigit()
            }
            TableColumn("Target") { pos in
                if let secId = pos.security?.id, let target = targets[secId] {
                    Text(FormatUtils.percent(target))
                        .monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            TableColumn("Drift") { pos in
                if let secId = pos.security?.id, let target = targets[secId] {
                    let weight = totalValue > 0 ? pos.currentValue / totalValue : 0
                    let drift = weight - target
                    Text(FormatUtils.percentChange(drift))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnl(drift))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            TableColumn("P&L") { pos in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(FormatUtils.currency(pos.openPnl, currency: pos.currency))
                        .monospacedDigit()
                        .foregroundStyle(Color.pnl(pos.openPnl))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text(FormatUtils.currency(totalValue, currency: group.baseCurrency))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}
