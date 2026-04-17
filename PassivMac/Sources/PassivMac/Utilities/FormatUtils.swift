import Foundation

enum FormatUtils {

    // MARK: - Currency

    static func currency(_ value: Double, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = currency.locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)\(value)"
    }

    static func currencyCompact(_ value: Double, currency: Currency) -> String {
        let abs = Swift.abs(value)
        let sign = value < 0 ? "-" : ""
        switch abs {
        case 1_000_000...:
            return "\(sign)\(currency.symbol)\(String(format: "%.1fM", abs / 1_000_000))"
        case 1_000...:
            return "\(sign)\(currency.symbol)\(String(format: "%.1fK", abs / 1_000))"
        default:
            return FormatUtils.currency(value, currency: currency)
        }
    }

    // MARK: - Percentage

    static func percent(_ fraction: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", fraction * 100)
    }

    static func percentChange(_ fraction: Double) -> String {
        let sign = fraction >= 0 ? "+" : ""
        return "\(sign)\(percent(fraction))"
    }

    // MARK: - Shares / quantity

    static func shares(_ quantity: Double) -> String {
        if quantity == quantity.rounded() {
            return String(format: "%.0f", quantity)
        }
        return String(format: "%.4f", quantity)
    }

    // MARK: - Date

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
