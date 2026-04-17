import SwiftUI

struct TradeRowView: View {
    let trade: RebalanceEngine.TradeInstruction
    let isExcluded: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Exclude toggle
            Image(systemName: isExcluded ? "circle" : "checkmark.circle.fill")
                .foregroundStyle(isExcluded ? .secondary : .blue)
                .font(.title3)
                .onTapGesture { onToggle() }

            // Action badge
            Text(trade.action.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundStyle(trade.action == .buy ? .white : .white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(trade.action == .buy ? Color.green : Color.red,
                            in: Capsule())

            // Symbol + details
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.symbol).fontWeight(.medium)
                Text("\(FormatUtils.shares(trade.quantity)) shares @ \(FormatUtils.currency(trade.estimatedPrice, currency: .cad))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Estimated cost
            Text(FormatUtils.currency(trade.estimatedCost, currency: .cad))
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(isExcluded ? .secondary : .primary)
        }
        .opacity(isExcluded ? 0.5 : 1.0)
        .contentShape(Rectangle())
    }
}
