import SwiftUI
import Charts

struct PerformanceView: View {
    let group: PortfolioGroup

    @State private var range: TimeRange = .oneMonth

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneWeek  = "1W"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear  = "1Y"
        case all      = "All"

        var id: String { rawValue }

        var cutoff: Date? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .oneWeek:     return cal.date(byAdding: .day,   value: -7,   to: now)
            case .oneMonth:    return cal.date(byAdding: .month, value: -1,   to: now)
            case .threeMonths: return cal.date(byAdding: .month, value: -3,   to: now)
            case .sixMonths:   return cal.date(byAdding: .month, value: -6,   to: now)
            case .oneYear:     return cal.date(byAdding: .year,  value: -1,   to: now)
            case .all:         return nil
            }
        }
    }

    private var filteredSnapshots: [PortfolioSnapshot] {
        let all = group.snapshots.sorted { $0.recordedAt < $1.recordedAt }
        guard let cutoff = range.cutoff else { return all }
        return all.filter { $0.recordedAt >= cutoff }
    }

    private var currentValue: Double {
        group.accounts.reduce(0) { $0 + $1.totalMarketValue + $1.cashBalance }
    }

    private var twr: Double {
        let points = filteredSnapshots.enumerated().map { (i, snap) -> PortfolioCalculator.SnapshotPoint in
            let contributions = i == 0 ? 0 : snap.netContributions - filteredSnapshots[i - 1].netContributions
            return PortfolioCalculator.SnapshotPoint(
                date: snap.recordedAt,
                totalValue: snap.totalValue,
                periodContributions: contributions
            )
        }
        return PortfolioCalculator.timeWeightedReturn(snapshots: points)
    }

    private var totalReturn: Double {
        guard let first = filteredSnapshots.first else { return 0 }
        return PortfolioCalculator.totalReturn(currentValue: currentValue, netContributions: first.netContributions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Range picker
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Stats strip
                HStack(spacing: 0) {
                    statCell(
                        label: "Portfolio Value",
                        value: FormatUtils.currency(currentValue, currency: group.baseCurrency)
                    )
                    Divider()
                    statCell(
                        label: "Total Return",
                        value: FormatUtils.percentChange(totalReturn),
                        valueColor: Color.pnl(totalReturn)
                    )
                    Divider()
                    statCell(
                        label: "TWR (\(range.rawValue))",
                        value: FormatUtils.percentChange(twr),
                        valueColor: Color.pnl(twr)
                    )
                }
                .frame(height: 72)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Chart
                if filteredSnapshots.count >= 2 {
                    Chart(filteredSnapshots) { snap in
                        LineMark(
                            x: .value("Date", snap.recordedAt),
                            y: .value("Value", snap.totalValue)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", snap.recordedAt),
                            y: .value("Value", snap.totalValue)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.blue.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(FormatUtils.currencyCompact(v, currency: group.baseCurrency))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Sync your accounts a few times to build a performance history.")
                    )
                    .frame(height: 220)
                }

                // Dividends
                let allDividends = group.accounts.flatMap { $0.dividends }
                    .sorted { $0.paidAt > $1.paidAt }
                if !allDividends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dividend History")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(allDividends.prefix(20)) { div in
                            HStack {
                                Text(div.symbol).fontWeight(.medium)
                                Spacer()
                                Text(FormatUtils.currency(div.amount, currency: div.currency))
                                Text(div.paidAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func statCell(label: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).foregroundStyle(valueColor).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
