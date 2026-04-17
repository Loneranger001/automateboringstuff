import Foundation
import SwiftData

/// A live order submitted to a brokerage. Tracks fill status.
@Model
final class Order {
    var id: UUID
    var calculatedTradeId: UUID
    var brokerageOrderId: String    // external ID from brokerage
    var accountId: UUID
    var symbol: String
    var actionRaw: String           // TradeAction raw value
    var orderTypeRaw: String        // OrderType raw value
    var quantity: Double
    var limitPrice: Double          // 0 if market order
    var filledQuantity: Double
    var filledPrice: Double
    var statusRaw: String           // TradeStatus raw value
    var currencyRaw: String
    var submittedAt: Date
    var filledAt: Date?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        calculatedTradeId: UUID,
        brokerageOrderId: String,
        accountId: UUID,
        symbol: String,
        action: TradeAction,
        orderType: OrderType,
        quantity: Double,
        limitPrice: Double = 0,
        currency: Currency
    ) {
        self.id = id
        self.calculatedTradeId = calculatedTradeId
        self.brokerageOrderId = brokerageOrderId
        self.accountId = accountId
        self.symbol = symbol
        self.actionRaw = action.rawValue
        self.orderTypeRaw = orderType.rawValue
        self.quantity = quantity
        self.limitPrice = limitPrice
        self.filledQuantity = 0
        self.filledPrice = 0
        self.statusRaw = TradeStatus.submitted.rawValue
        self.currencyRaw = currency.rawValue
        self.submittedAt = Date()
    }

    var action: TradeAction {
        get { TradeAction(rawValue: actionRaw) ?? .buy }
        set { actionRaw = newValue.rawValue }
    }

    var orderType: OrderType {
        get { OrderType(rawValue: orderTypeRaw) ?? .market }
        set { orderTypeRaw = newValue.rawValue }
    }

    var status: TradeStatus {
        get { TradeStatus(rawValue: statusRaw) ?? .submitted }
        set { statusRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .cad }
        set { currencyRaw = newValue.rawValue }
    }

    var isFinal: Bool {
        status == .filled || status == .failed || status == .cancelled
    }
}
