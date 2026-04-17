import SwiftUI
import SwiftData

struct TargetAllocationEditorView: View {
    @Bindable var group: PortfolioGroup
    @Environment(\.modelContext) private var context

    @State private var showSymbolSearch = false
    @State private var totalPercent: Double = 0

    private var sortedAllocations: [TargetAllocation] {
        group.targetAllocations.sorted { $0.targetPercent > $1.targetPercent }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Accuracy meter bar
            accuracyBar

            List {
                ForEach(sortedAllocations) { allocation in
                    AllocationRowView(allocation: allocation) {
                        context.delete(allocation)
                        group.targetAllocations.removeAll { $0.id == allocation.id }
                        try? context.save()
                        recalcTotal()
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let al = sortedAllocations[index]
                        context.delete(al)
                        group.targetAllocations.removeAll { $0.id == al.id }
                    }
                    try? context.save()
                    recalcTotal()
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button {
                    showSymbolSearch = true
                } label: {
                    Label("Add Security", systemImage: "plus")
                }

                Spacer()

                totalLabel
            }
            .padding()
        }
        .onAppear { recalcTotal() }
        .sheet(isPresented: $showSymbolSearch) {
            SymbolSearchSheet(group: group) { recalcTotal() }
        }
    }

    // MARK: - Subviews

    private var accuracyBar: some View {
        let holdings: [(securityId: UUID, currentValue: Double)] = group.accounts
            .flatMap { $0.positions }
            .compactMap { pos in
                guard let sec = pos.security else { return nil }
                return (sec.id, pos.currentValue)
            }
        let targets: [(securityId: UUID, targetPercent: Double)] = group.targetAllocations
            .compactMap { t in
                guard let sec = t.security else { return nil }
                return (sec.id, t.targetPercent)
            }
        let totalValue = group.accounts.reduce(0.0) { $0 + $1.totalMarketValue + $1.cashBalance }
        let accuracy = PortfolioCalculator.accuracy(holdings: holdings, targets: targets, totalValue: totalValue)

        return HStack(spacing: 16) {
            Text("Portfolio Accuracy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: accuracy)
                .tint(Color.accuracy(accuracy))
            Text(FormatUtils.percent(accuracy))
                .font(.subheadline.bold())
                .foregroundStyle(Color.accuracy(accuracy))
                .monospacedDigit()
                .frame(width: 48)
        }
        .padding()
        .background(.background.secondary)
    }

    private var totalLabel: some View {
        let isValid = abs(totalPercent - 1.0) < 0.001
        return HStack(spacing: 4) {
            Text("Total:")
            Text(FormatUtils.percent(totalPercent))
                .fontWeight(.semibold)
                .foregroundStyle(isValid ? .primary : .red)
            if !isValid {
                Text("(must equal 100%)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func recalcTotal() {
        totalPercent = group.targetAllocations.reduce(0) { $0 + $1.targetPercent }
    }
}

struct AllocationRowView: View {
    @Bindable var allocation: TargetAllocation
    @Environment(\.modelContext) private var context
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(allocation.symbol).fontWeight(.medium)
                Text(allocation.security?.name ?? "").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", value: Binding(
                    get: { allocation.targetPercent * 100 },
                    set: { allocation.targetPercent = $0 / 100 }
                ), format: .number.precision(.fractionLength(1)))
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .textFieldStyle(.roundedBorder)
                Text("%").foregroundStyle(.secondary)
            }

            Toggle("Exclude", isOn: $allocation.excludeFromRebalance)
                .labelsHidden()
                .help(allocation.excludeFromRebalance ? "Excluded from rebalance" : "Include in rebalance")

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .onChange(of: allocation.targetPercent) { _, _ in
            try? context.save()
        }
    }
}
