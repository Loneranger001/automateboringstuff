import SwiftUI

struct PortfolioGroupCardView: View {
    let group: PortfolioGroup

    private var totalValue: Double {
        group.accounts.reduce(0) { $0 + $1.totalMarketValue + $1.cashBalance }
    }

    private var totalCash: Double {
        group.accounts.reduce(0) { $0 + $1.cashBalance }
    }

    private var holdings: [(securityId: UUID, currentValue: Double)] {
        group.accounts.flatMap { $0.positions }.compactMap { pos in
            guard let sec = pos.security else { return nil }
            return (sec.id, pos.currentValue)
        }
    }

    private var targets: [(securityId: UUID, targetPercent: Double)] {
        group.targetAllocations.compactMap { t in
            guard let sec = t.security else { return nil }
            return (sec.id, t.targetPercent)
        }
    }

    private var accuracy: Double {
        PortfolioCalculator.accuracy(
            holdings: holdings,
            targets: targets,
            totalValue: totalValue
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.name).font(.headline)
                Spacer()
                if !group.hasTargets {
                    Text("Setup Required")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            Text(FormatUtils.currencyCompact(totalValue, currency: group.baseCurrency))
                .font(.title2.bold())

            HStack(spacing: 16) {
                // Accuracy ring
                AccuracyRing(accuracy: accuracy)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Label(FormatUtils.percent(accuracy), systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(Color.accuracy(accuracy))
                    if totalCash > 0 {
                        Label(FormatUtils.currency(totalCash, currency: group.baseCurrency) + " cash", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let synced = group.accounts.compactMap(\.connection?.lastSyncedAt).max() {
                        Label("Synced " + FormatUtils.relativeDate(synced), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

struct AccuracyRing: View {
    let accuracy: Double  // 0.0 – 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: accuracy)
                .stroke(Color.accuracy(accuracy), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: accuracy)
            Text(FormatUtils.percent(accuracy, decimals: 0))
                .font(.caption2.bold())
        }
    }
}
