import Foundation

/// Token-bucket rate limiter — enforces a minimum interval between requests per brokerage.
actor RateLimiter {

    private var lastRequestTime: [BrokerageType: Date] = [:]

    /// Minimum seconds between requests for each brokerage.
    private let minimumInterval: [BrokerageType: TimeInterval] = [
        .questrade: 0.6,   // ~100 req/min soft limit → 0.6s between calls
        .ibkr:      1.0,
    ]

    /// Waits if needed, then records this request time.
    func throttle(for brokerage: BrokerageType) async {
        let interval = minimumInterval[brokerage] ?? 1.0
        if let last = lastRequestTime[brokerage] {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < interval {
                let wait = interval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
        lastRequestTime[brokerage] = Date()
    }
}
