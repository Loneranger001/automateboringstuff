import SwiftUI

struct PortfolioGroupCardView: View {
    let group: PortfolioGroup

    /// USD→CAD rate — how many CAD equal 1 USD. Loaded from FXRateService;
    /// falls back to the persisted "last good" rate from Bank of Canada, and
    /// a hardcoded floor if even that's unavailable.
    @State private var usdCadRate: Double = 1.36

    private var totalValue: Double {
        PortfolioCalculator.totalValueInBase(group: group, usdCadRate: usdCadRate)
    }

    private var totalCash: Double {
        PortfolioCalculator.totalCashInBase(group: group, usdCadRate: usdCadRate)
    }

    private var holdings: [(securityId: UUID, currentValue: Double)] {
        // Convert each position's native currency value to base currency so
        // the accuracy ring compares like-with-like.
        group.accounts.flatMap { acct in
            acct.positions.compactMap { pos -> (UUID, Double)? in
                guard let sec = pos.security else { return nil }
                let rate = PortfolioCalculator.conversionRate(
                    from: acct.currency, to: group.baseCurrency, usdCadRate: usdCadRate
                )
                return (sec.id, pos.currentValue * rate)
            }
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
        .task {
            // Fetch the latest USD→CAD rate once when the card appears.
            // FXRateService caches for an hour and persists last-good to UserDefaults.
            usdCadRate = await FXRateService.shared.rate(from: .usd, to: .cad)
        }
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
