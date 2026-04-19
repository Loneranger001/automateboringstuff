import SwiftUI
import SwiftData

struct RebalanceView: View {
    let group: PortfolioGroup
    @Environment(\.modelContext) private var context

    @State private var mode: RebalanceMode = .buyOnly
    @State private var trades: [RebalanceEngine.TradeInstruction] = []
    @State private var excludedIds = Set<UUID>()
    @State private var showConfirmation = false
    @State private var isCalculating = false

    private var totalCash: Double {
        group.accounts.reduce(0) { $0 + $1.cashBalance }
    }

    private var totalBuyCost: Double {
        activeTrades.filter { $0.action == .buy }.reduce(0) { $0 + $1.estimatedCost }
    }

    private var activeTrades: [RebalanceEngine.TradeInstruction] {
        trades.filter { !excludedIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if trades.isEmpty && !isCalculating {
                emptyState
            } else {
                tradeList
            }

            Divider()
            footer
        }
        .task { calculate() }
        .sheet(isPresented: $showConfirmation) {
            OrderConfirmationSheet(
                trades: activeTrades,
                group: group
            ) {
                // Refresh after execution
                Task {
                    await SyncService.shared.syncAll(context: context)
                    calculate()
                }
            }
        }
    }

    // MARK: - Subviews

    private var toolbar: some View {
        HStack {
            Picker("Mode", selection: $mode) {
                ForEach(RebalanceMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            Button {
                calculate()
            } label: {
                Label("Recalculate", systemImage: "arrow.clockwise")
            }
            .disabled(isCalculating)
        }
        .padding()
        .background(.background.secondary)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            group.hasTargets ? "Portfolio is Balanced" : "No Targets Set",
            systemImage: group.hasTargets ? "checkmark.circle" : "target",
            description: Text(group.hasTargets
                ? "No trades needed — your portfolio is within tolerance."
                : "Set up target allocations in the Targets tab first.")
        )
        .frame(maxHeight: .infinity)
    }

    private var tradeList: some View {
        List {
            if isCalculating {
                Section { ProgressView("Calculating trades…") }
            } else {
                Section {
                    ForEach(trades) { trade in
                        TradeRowView(
                            trade: trade,
                            isExcluded: excludedIds.contains(trade.id)
                        ) {
                            if excludedIds.contains(trade.id) {
                                excludedIds.remove(trade.id)
                            } else {
                                excludedIds.insert(trade.id)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("\(trades.count) trades calculated")
                        Spacer()
                        Text("Cash available: \(FormatUtils.currency(totalCash, currency: group.baseCurrency))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(activeTrades.count) active trades")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Est. total: \(FormatUtils.currency(totalBuyCost, currency: group.baseCurrency))")
                    .font(.subheadline.bold())
            }

            Spacer()

            Button {
                showConfirmation = true
            } label: {
                Label("Place All Orders", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeTrades.isEmpty)
        }
        .padding()
    }

    // MARK: - Calculation

    private func calculate() {
        isCalculating = true
        excludedIds = []

        let allPositions = group.accounts.flatMap { $0.positions }
        // The same security can be held in multiple accounts (e.g. VEQT in TFSA and RRSP),
        // which produces duplicate keys. `Dictionary(uniqueKeysWithValues:)` traps on
        // duplicates, so collapse by taking the last price — it's the same security, so
        // any occurrence's price is equivalent.
        let currentPrices: [UUID: Double] = Dictionary(
            allPositions.compactMap { pos -> (UUID, Double)? in
                guard let sec = pos.security else { return nil }
                return (sec.id, sec.lastPrice)
            },
            uniquingKeysWith: { _, new in new }
        )

        // Assign each security to the account that holds it, or first account if not yet held
        var assignments: [UUID: UUID] = [:]
        for allocation in group.targetAllocations where !allocation.excludeFromRebalance {
            guard let sec = allocation.security else { continue }
            if let holding = allPositions.first(where: { $0.security?.id == sec.id }),
               let account = holding.account {
                assignments[sec.id] = account.id
            } else if let firstAccount = group.accounts.first {
                assignments[sec.id] = firstAccount.id
            }
        }

        // Aggregate by securityId across accounts — RebalanceEngine looks up holdings
        // via `.first(where:)`, so without aggregation a security held in multiple
        // accounts would be under-reported (only the first account's value counted).
        var holdingsBySecurity: [UUID: Double] = [:]
        for pos in allPositions {
            guard let sec = pos.security else { continue }
            holdingsBySecurity[sec.id, default: 0] += pos.currentValue
        }
        let holdings: [(securityId: UUID, currentValue: Double)] =
            holdingsBySecurity.map { (securityId: $0.key, currentValue: $0.value) }

        let targetAllocations: [(securityId: UUID, symbol: String, targetPercent: Double)] =
            group.targetAllocations
                .filter { !$0.excludeFromRebalance }
                .compactMap { t in
                    guard let sec = t.security else { return nil }
                    return (sec.id, t.symbol, t.targetPercent)
                }

        let input = RebalanceEngine.Input(
            targetAllocations: targetAllocations,
            currentHoldings: holdings,
            availableCash: totalCash,
            currentPrices: currentPrices,
            accountAssignments: assignments,
            mode: mode
        )

        trades = RebalanceEngine.calculate(input)
        isCalculating = false
    }
}
