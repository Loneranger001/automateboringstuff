import Foundation

/// Token-bucket rate limiter — enforces a minimum interval between requests per brokerage
/// and honors server-side backoff signals (HTTP 429 Retry-After).
actor RateLimiter {

    private var lastRequestTime: [BrokerageType: Date] = [:]
    /// When set, no requests for this brokerage may fire until the date passes.
    private var backoffUntil: [BrokerageType: Date] = [:]
    /// Consecutive 429 count, for exponential backoff when `Retry-After` is absent.
    private var consecutive429: [BrokerageType: Int] = [:]

    /// Minimum seconds between requests for each brokerage.
    private let minimumInterval: [BrokerageType: TimeInterval] = [
        .questrade: 0.6,   // ~100 req/min soft limit → 0.6s between calls
        .ibkr:      1.0,
    ]

    /// Hard cap on backoff — avoid sleeping for hours on a buggy server response.
    private let maxBackoff: TimeInterval = 5 * 60

    /// Waits if needed, then records this request time.
    func throttle(for brokerage: BrokerageType) async {
        // Server-dictated backoff always wins.
        if let until = backoffUntil[brokerage] {
            let remaining = until.timeIntervalSince(Date())
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(min(remaining, maxBackoff) * 1_000_000_000))
            }
            backoffUntil[brokerage] = nil
        }

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

    /// Record a 429 rate-limit response. `retryAfter` comes from the server's
    /// `Retry-After` header when present; otherwise we fall back to exponential
    /// backoff based on how many 429s we've seen in a row.
    func recordRateLimit(for brokerage: BrokerageType, retryAfter: TimeInterval?) {
        let n = (consecutive429[brokerage] ?? 0) + 1
        consecutive429[brokerage] = n
        let backoff = retryAfter ?? min(pow(2.0, Double(n)), maxBackoff)
        backoffUntil[brokerage] = Date().addingTimeInterval(min(backoff, maxBackoff))
    }

    /// Call after a successful (non-429) response to reset exponential backoff state.
    func recordSuccess(for brokerage: BrokerageType) {
        consecutive429[brokerage] = 0
    }
}
