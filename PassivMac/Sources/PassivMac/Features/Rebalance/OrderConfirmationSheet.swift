import SwiftUI
import SwiftData

struct OrderConfirmationSheet: View {
    let trades: [RebalanceEngine.TradeInstruction]
    let group: PortfolioGroup
    var onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var orderType: OrderType = .market
    @State private var isExecuting = false
    @State private var results: [OrderResult] = []
    @State private var phase: Phase = .confirm

    enum Phase { case confirm, executing, done }

    struct OrderResult: Identifiable {
        let id = UUID()
        let symbol: String
        let action: TradeAction
        let quantity: Double
        var status: TradeStatus = .submitted
        var errorMessage: String?
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .confirm: confirmView
                case .executing: executingView
                case .done: doneView
                }
            }
            .navigationTitle("Confirm Orders")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if phase != .executing {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if phase == .confirm {
                        Button("Place \(trades.count) Orders") {
                            Task { await executeOrders() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(trades.isEmpty)
                    }
                    if phase == .done {
                        Button("Done") {
                            dismiss()
                            onComplete()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - Confirm phase

    private var confirmView: some View {
        Form {
            Section("Order Type") {
                Picker("Order Type", selection: $orderType) {
                    ForEach(OrderType.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.segmented)
                if orderType == .market {
                    Text("Market orders execute at the current market price.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Limit orders will use each security's last known price as the limit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Orders to Place") {
                ForEach(trades) { trade in
                    HStack {
                        Text(trade.action.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(trade.action == .buy ? .green : .red)
                        Text(trade.symbol).fontWeight(.medium)
                        Spacer()
                        Text("\(FormatUtils.shares(trade.quantity)) shares")
                        Text(FormatUtils.currency(trade.estimatedCost, currency: .cad))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Text("Estimated Total").fontWeight(.semibold)
                    Spacer()
                    Text(FormatUtils.currency(
                        trades.reduce(0) { $0 + $1.estimatedCost },
                        currency: group.baseCurrency
                    ))
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Executing phase

    private var executingView: some View {
        List(results) { result in
            HStack {
                statusIcon(result.status)
                Text(result.symbol).fontWeight(.medium)
                Text("\(result.action.rawValue) \(FormatUtils.shares(result.quantity))")
                    .foregroundStyle(.secondary)
                Spacer()
                if let err = result.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Done phase

    private var doneView: some View {
        let filled = results.filter { $0.status == .filled }.count
        let failed  = results.filter { $0.status == .failed }.count

        return VStack(spacing: 24) {
            Image(systemName: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(failed == 0 ? .green : .orange)
            Text(failed == 0 ? "All Orders Placed" : "\(filled) Placed, \(failed) Failed")
                .font(.title2.bold())
            List(results) { result in
                HStack {
                    statusIcon(result.status)
                    Text(result.symbol)
                    Spacer()
                    if let err = result.errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func statusIcon(_ status: TradeStatus) -> some View {
        switch status {
        case .submitted:
            ProgressView().controlSize(.small)
        case .filled:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed, .cancelled:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        default:
            Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }

    // MARK: - Execution

    private func executeOrders() async {
        phase = .executing
        results = trades.map { OrderResult(symbol: $0.symbol, action: $0.action, quantity: $0.quantity) }

        let provider = QuestradeProvider()

        for (index, trade) in trades.enumerated() {
            guard let account = group.accounts.first(where: { $0.id == trade.targetAccountId }) else {
                results[index].status = .failed
                results[index].errorMessage = "Account not found"
                continue
            }

            guard let connection = account.connection else {
                results[index].status = .failed
                results[index].errorMessage = "No brokerage connection"
                continue
            }

            let request = OrderRequest(
                accountId: account.brokerageAccountId,
                symbol: trade.symbol,
                action: trade.action,
                orderType: orderType,
                quantity: trade.quantity,
                limitPrice: orderType == .limit ? trade.estimatedPrice : nil
            )

            do {
                let remoteOrder = try await provider.placeOrder(request, connectionId: connection.id)
                results[index].status = remoteOrder.status

                // Persist order record
                let order = Order(
                    calculatedTradeId: trade.id,
                    brokerageOrderId: remoteOrder.brokerageOrderId,
                    accountId: account.id,
                    symbol: trade.symbol,
                    action: trade.action,
                    orderType: orderType,
                    quantity: trade.quantity,
                    limitPrice: orderType == .limit ? trade.estimatedPrice : 0,
                    currency: account.currency
                )
                context.insert(order)

                if remoteOrder.status == .filled {
                    NotificationService.shared.notifyOrderFilled(
                        symbol: trade.symbol,
                        quantity: trade.quantity,
                        action: trade.action
                    )
                }
            } catch {
                results[index].status = .failed
                results[index].errorMessage = error.localizedDescription
            }
        }

        try? context.save()
        phase = .done
    }
}
