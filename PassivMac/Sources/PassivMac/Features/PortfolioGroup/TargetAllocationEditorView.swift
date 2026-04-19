import SwiftUI
import SwiftData

/// Model-portfolio–style target editor, inspired by Passiv's "Model Portfolio" UI
/// (https://passiv.com/help/tutorials/how-to-use-model-portfolio/).
///
/// Layout:
///   ┌────────────────────────────────────────────────────────────────┐
///   │ Portfolio Accuracy  [████████░░]  82%         Total CAD value │
///   ├────────────────────────────────────────────────────────────────┤
///   │ Symbol / Name       Target  Current  Drift   Value    ≡  ✕    │
///   │ VFV                 40.0%    38.2%   -1.8%   $38,200  ⇊  ✕    │
///   │ XAW                 30.0%    31.5%   +1.5%   $31,500  ⇊  ✕    │
///   │  …                                                             │
///   │ Unassigned holdings (held but not in target)                   │
///   │ VCN                 —        12.3%   +12.3%  $12,300  ⇊  ✕    │
///   ├────────────────────────────────────────────────────────────────┤
///   │ [+ Add Security]                            Total: 100.0% ✓    │
///   └────────────────────────────────────────────────────────────────┘
///
/// Drift color code:
///   |drift| ≤ 1%   green (on target)
///   |drift| ≤ 3%   yellow (minor)
///   |drift| > 3%   red   (needs rebalance)
struct TargetAllocationEditorView: View {
    @Bindable var group: PortfolioGroup
    @Environment(\.modelContext) private var context

    @State private var showSymbolSearch = false
    @State private var usdCadRate: Double = 1.36

    private var sortedAllocations: [TargetAllocation] {
        group.targetAllocations.sorted { $0.targetPercent > $1.targetPercent }
    }

    /// Holdings that don't have a matching target allocation — e.g. legacy
    /// positions the user hasn't added to their model yet. Shown in a separate
    /// "Unassigned" section so they're visible as drift rather than silently ignored.
    private var unassignedPositions: [(security: Security, valueInBase: Double)] {
        let targetSecurityIds = Set(group.targetAllocations.compactMap { $0.security?.id })
        // Aggregate positions by security across accounts, converting each to base currency.
        var byId: [UUID: (Security, Double)] = [:]
        for account in group.accounts {
            let rate = PortfolioCalculator.conversionRate(
                from: account.currency, to: group.baseCurrency, usdCadRate: usdCadRate
            )
            for pos in account.positions {
                guard let sec = pos.security, !targetSecurityIds.contains(sec.id) else { continue }
                let contribution = pos.currentValue * rate
                if let (existing, total) = byId[sec.id] {
                    byId[sec.id] = (existing, total + contribution)
                } else {
                    byId[sec.id] = (sec, contribution)
                }
            }
        }
        return byId.values
            .map { (security: $0.0, valueInBase: $0.1) }
            .sorted { $0.valueInBase > $1.valueInBase }
    }

    private var totalValueBase: Double {
        PortfolioCalculator.totalValueInBase(group: group, usdCadRate: usdCadRate)
    }

    private var totalTargetPercent: Double {
        group.targetAllocations.reduce(0) { $0 + $1.targetPercent }
    }

    var body: some View {
        VStack(spacing: 0) {
            accuracyBar

            List {
                targetsSection

                if !unassignedPositions.isEmpty {
                    unassignedSection
                }
            }
            .listStyle(.inset)

            Divider()
            footerBar
        }
        .sheet(isPresented: $showSymbolSearch) {
            SymbolSearchSheet(group: group) { /* row updates reactively via @Bindable */ }
        }
        .task {
            usdCadRate = await FXRateService.shared.rate(from: .usd, to: .cad)
        }
    }

    // MARK: - Accuracy bar (header)

    private var accuracyBar: some View {
        let holdings: [(securityId: UUID, currentValue: Double)] = group.accounts
            .flatMap { acct in
                let rate = PortfolioCalculator.conversionRate(
                    from: acct.currency, to: group.baseCurrency, usdCadRate: usdCadRate
                )
                return acct.positions.compactMap { pos -> (UUID, Double)? in
                    guard let sec = pos.security else { return nil }
                    return (sec.id, pos.currentValue * rate)
                }
            }
        let targets: [(securityId: UUID, targetPercent: Double)] = group.targetAllocations
            .compactMap { t in
                guard let sec = t.security else { return nil }
                return (sec.id, t.targetPercent)
            }
        let accuracy = PortfolioCalculator.accuracy(
            holdings: holdings, targets: targets, totalValue: totalValueBase
        )

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio Accuracy")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(FormatUtils.currency(totalValueBase, currency: group.baseCurrency))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            ProgressView(value: accuracy)
                .tint(Color.accuracy(accuracy))
            Text(FormatUtils.percent(accuracy))
                .font(.subheadline.bold())
                .foregroundStyle(Color.accuracy(accuracy))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
        .padding()
        .background(.background.secondary)
    }

    // MARK: - Targets section

    private var targetsSection: some View {
        Section {
            if sortedAllocations.isEmpty {
                ContentUnavailableView(
                    "No targets yet",
                    systemImage: "target",
                    description: Text("Add securities with desired allocation percentages to build your model portfolio.")
                )
                .listRowBackground(Color.clear)
            } else {
                // Column headers
                AllocationHeaderRow()
                    .listRowSeparator(.hidden)

                ForEach(sortedAllocations) { allocation in
                    AllocationRow(
                        allocation: allocation,
                        totalValueBase: totalValueBase,
                        baseCurrency: group.baseCurrency,
                        usdCadRate: usdCadRate,
                        accounts: group.accounts,
                        onDelete: { delete(allocation) }
                    )
                }
            }
        } header: {
            Text("Target Allocations")
        }
    }

    // MARK: - Unassigned section

    private var unassignedSection: some View {
        Section {
            AllocationHeaderRow()
                .listRowSeparator(.hidden)
            ForEach(unassignedPositions, id: \.security.id) { item in
                UnassignedRow(
                    security: item.security,
                    valueInBase: item.valueInBase,
                    totalValueBase: totalValueBase,
                    baseCurrency: group.baseCurrency,
                    onAdopt: { adopt(item.security) }
                )
            }
        } header: {
            HStack {
                Text("Unassigned Holdings")
                Spacer()
                Text("Not in your target — treated as 100% drift")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button {
                showSymbolSearch = true
            } label: {
                Label("Add Security", systemImage: "plus")
            }

            Spacer()

            totalTargetLabel
        }
        .padding()
    }

    private var totalTargetLabel: some View {
        let total = totalTargetPercent
        let isValid = abs(total - 1.0) < 0.001
        return HStack(spacing: 6) {
            Text("Total:")
                .foregroundStyle(.secondary)
            Text(FormatUtils.percent(total))
                .fontWeight(.semibold)
                .foregroundStyle(isValid ? AnyShapeStyle(.green) : AnyShapeStyle(Color.red))
                .monospacedDigit()
            if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("(must equal 100%)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func delete(_ allocation: TargetAllocation) {
        context.delete(allocation)
        group.targetAllocations.removeAll { $0.id == allocation.id }
        try? context.save()
    }

    /// Promote an unassigned holding into the target list with 0% target (user sets it after).
    private func adopt(_ security: Security) {
        guard !group.targetAllocations.contains(where: { $0.security?.id == security.id }) else { return }
        let allocation = TargetAllocation(
            portfolioGroup: group,
            security: security,
            symbol: security.symbol,
            targetPercent: 0
        )
        context.insert(allocation)
        group.targetAllocations.append(allocation)
        try? context.save()
    }
}

// MARK: - Column header

private struct AllocationHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Symbol")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Target")
                .frame(width: 72, alignment: .trailing)
            Text("Current")
                .frame(width: 72, alignment: .trailing)
            Text("Drift")
                .frame(width: 72, alignment: .trailing)
            Text("Value")
                .frame(width: 96, alignment: .trailing)
            Spacer().frame(width: 28)   // exclude toggle
            Spacer().frame(width: 24)   // delete
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Allocation row

private struct AllocationRow: View {
    @Bindable var allocation: TargetAllocation
    let totalValueBase: Double
    let baseCurrency: Currency
    let usdCadRate: Double
    let accounts: [Account]
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context

    /// Sum of this security's current value across all accounts, in base currency.
    private var currentValueInBase: Double {
        guard let secId = allocation.security?.id else { return 0 }
        return accounts.reduce(0) { acc, account in
            let rate = PortfolioCalculator.conversionRate(
                from: account.currency, to: baseCurrency, usdCadRate: usdCadRate
            )
            let v = account.positions
                .filter { $0.security?.id == secId }
                .reduce(0) { $0 + $1.currentValue * rate }
            return acc + v
        }
    }

    private var currentWeight: Double {
        totalValueBase > 0 ? currentValueInBase / totalValueBase : 0
    }

    private var drift: Double {
        currentWeight - allocation.targetPercent
    }

    var body: some View {
        HStack(spacing: 12) {
            // Symbol + name
            VStack(alignment: .leading, spacing: 2) {
                Text(allocation.symbol).fontWeight(.medium)
                if let name = allocation.security?.name, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Target % (editable)
            HStack(spacing: 2) {
                TextField("0", value: Binding(
                    get: { allocation.targetPercent * 100 },
                    set: { newValue in
                        // Clamp to [0, 100] and reject NaN/Infinity.
                        let sanitized = newValue.isFinite ? min(max(newValue, 0), 100) : 0
                        allocation.targetPercent = sanitized / 100
                    }
                ), format: .number.precision(.fractionLength(1)))
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .textFieldStyle(.roundedBorder)
                Text("%").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 72, alignment: .trailing)

            // Current %
            Text(FormatUtils.percent(currentWeight))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.secondary)

            // Drift with color coding
            Text(FormatUtils.percentChange(drift))
                .monospacedDigit()
                .foregroundStyle(Self.driftColor(drift))
                .frame(width: 72, alignment: .trailing)

            // Value in base currency
            Text(FormatUtils.currencyCompact(currentValueInBase, currency: baseCurrency))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)

            // Exclude toggle
            Toggle("Exclude", isOn: $allocation.excludeFromRebalance)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(allocation.excludeFromRebalance ? "Excluded from rebalance" : "Include in rebalance")
                .frame(width: 28)

            // Delete
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
        .padding(.vertical, 2)
        .onChange(of: allocation.targetPercent) { _, _ in
            try? context.save()
        }
    }

    /// Passiv-style drift thresholds: on-target under ±1%, minor under ±3%, major above.
    private static func driftColor(_ drift: Double) -> Color {
        let absDrift = abs(drift)
        if absDrift <= 0.01 { return .green }
        if absDrift <= 0.03 { return .orange }
        return .red
    }
}

// MARK: - Unassigned row

private struct UnassignedRow: View {
    let security: Security
    let valueInBase: Double
    let totalValueBase: Double
    let baseCurrency: Currency
    var onAdopt: () -> Void

    private var weight: Double {
        totalValueBase > 0 ? valueInBase / totalValueBase : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(security.symbol).fontWeight(.medium)
                if !security.name.isEmpty {
                    Text(security.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // No target
            Text("—")
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .trailing)

            Text(FormatUtils.percent(weight))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.secondary)

            // Entire holding is drift (no target)
            Text(FormatUtils.percentChange(weight))
                .monospacedDigit()
                .foregroundStyle(.red)
                .frame(width: 72, alignment: .trailing)

            Text(FormatUtils.currencyCompact(valueInBase, currency: baseCurrency))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)

            Button {
                onAdopt()
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .help("Add to target allocations")
            .frame(width: 28)

            // No delete — these are derived from positions, not user-added.
            Spacer().frame(width: 24)
        }
        .padding(.vertical, 2)
    }
}
