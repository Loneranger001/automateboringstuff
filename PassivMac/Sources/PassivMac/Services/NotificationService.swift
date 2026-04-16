import Foundation
import UserNotifications

/// Schedules macOS system notifications for cash available and portfolio drift events.
@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Cash Available

    func notifyCashAvailable(groupName: String, amount: Double, currency: Currency, threshold: Double) {
        guard amount >= threshold else { return }
        let body = "\(FormatUtils.currency(amount, currency: currency)) is available to invest in \(groupName)."
        schedule(id: "cash_\(groupName)", title: "Cash Available", body: body)
    }

    // MARK: - Drift

    func notifyDrift(groupName: String, accuracy: Double) {
        let pct = String(format: "%.0f", accuracy * 100)
        let body = "\(groupName) is \(pct)% accurate. Consider rebalancing."
        schedule(id: "drift_\(groupName)", title: "Portfolio Drift Detected", body: body)
    }

    // MARK: - Order Filled

    func notifyOrderFilled(symbol: String, quantity: Double, action: TradeAction) {
        let verb = action == .buy ? "Bought" : "Sold"
        let body = "\(verb) \(FormatUtils.shares(quantity)) shares of \(symbol)."
        schedule(id: "order_\(symbol)_\(Date().timeIntervalSince1970)", title: "Order Filled", body: body)
    }

    // MARK: - Private

    private func schedule(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
