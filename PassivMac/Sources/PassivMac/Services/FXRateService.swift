import Foundation

/// Fetches CAD/USD exchange rates from the Bank of Canada public API.
/// Free, authoritative, no API key required.
///
/// Endpoint: https://www.bankofcanada.ca/valet/observations/FXCADUSD/json?recent=1
actor FXRateService {

    static let shared = FXRateService()

    private var cachedRates: [String: Double] = [:]
    private var lastFetchedAt: Date?
    private let cacheLifetime: TimeInterval = 3600  // 1 hour

    /// Max age before we refuse to silently use a stale cached rate and prefer
    /// surfacing the fallback (or an indication of staleness) to callers.
    private let staleLimit: TimeInterval = 24 * 3600   // 24 hours

    private let http = HTTPClient()

    private init() {
        // Hydrate from persisted last-good rate if any. Keeps FX sane across launches
        // even with no network.
        if let rate = UserDefaults.standard.object(forKey: "fx_last_usdcad") as? Double,
           let date = UserDefaults.standard.object(forKey: "fx_last_usdcad_at") as? Date,
           rate.isFinite, rate > 0 {
            cachedRates["USD_CAD"] = rate
            cachedRates["CAD_USD"] = 1.0 / rate
            lastFetchedAt = date
        }
    }

    // MARK: - Public

    struct Quote {
        let rate: Double
        let asOf: Date?
        let isStale: Bool      // older than staleLimit OR fell back to hardcoded rate
        let isFallback: Bool   // true → hardcoded value, no live/cached data
    }

    /// Returns how many units of `to` equal 1 unit of `from`.
    func rate(from: Currency, to: Currency) async -> Double {
        await quote(from: from, to: to).rate
    }

    /// Fully-detailed quote including staleness. Callers who care about accuracy
    /// (e.g. display dollar values) should check `isStale`.
    func quote(from: Currency, to: Currency) async -> Quote {
        if from == to { return Quote(rate: 1.0, asOf: Date(), isStale: false, isFallback: false) }
        let key = "\(from.rawValue)_\(to.rawValue)"
        if let cached = cachedRates[key], isCacheValid() {
            return Quote(rate: cached, asOf: lastFetchedAt, isStale: false, isFallback: false)
        }
        await fetchRates()
        if let rate = cachedRates[key] {
            let age = lastFetchedAt.map { Date().timeIntervalSince($0) } ?? .infinity
            return Quote(rate: rate, asOf: lastFetchedAt, isStale: age > staleLimit, isFallback: false)
        }
        return Quote(
            rate: fallbackRate(from: from, to: to),
            asOf: nil,
            isStale: true,
            isFallback: true
        )
    }

    /// Convert an amount from one currency to another.
    func convert(_ amount: Double, from: Currency, to: Currency) async -> Double {
        guard from != to else { return amount }
        let r = await rate(from: from, to: to)
        return amount * r
    }

    // MARK: - Private

    private func fetchRates() async {
        // Bank of Canada returns both FXCADUSD (CAD per 1 USD) and FXUSDCAD
        // We fetch FXUSDCAD: how many CAD does 1 USD cost
        guard let url = URL(string: "https://www.bankofcanada.ca/valet/observations/FXUSDCAD/json?recent=1") else {
            return
        }
        do {
            let response: BoCResponse = try await http.get(url)
            if let obs = response.observations.last,
               let value = obs.fxusdcad?.v,
               let rate = Double(value),
               rate.isFinite, rate > 0 {
                cachedRates["USD_CAD"] = rate
                cachedRates["CAD_USD"] = 1.0 / rate
                lastFetchedAt = Date()
                UserDefaults.standard.set(rate, forKey: "fx_last_usdcad")
                UserDefaults.standard.set(Date(), forKey: "fx_last_usdcad_at")
            }
        } catch {
            // Leave previous cache/persisted value in place; caller will receive
            // a stale flag via `quote(...)` if the data is older than `staleLimit`.
        }
    }

    private func isCacheValid() -> Bool {
        guard let last = lastFetchedAt else { return false }
        return Date().timeIntervalSince(last) < cacheLifetime
    }

    /// Hardcoded fallback if network is unavailable (stale but safe)
    private func fallbackRate(from: Currency, to: Currency) -> Double {
        switch (from, to) {
        case (.usd, .cad): return 1.36
        case (.cad, .usd): return 0.74
        default: return 1.0
        }
    }

    // MARK: - Decodable DTOs

    private struct BoCResponse: Decodable {
        let observations: [Observation]

        struct Observation: Decodable {
            let d: String                   // date
            let fxusdcad: FXValue?

            enum CodingKeys: String, CodingKey {
                case d
                case fxusdcad = "FXUSDCAD"
            }
        }

        struct FXValue: Decodable {
            let v: String                   // value as string
        }
    }
}
