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

    private let http = HTTPClient()

    private init() {}

    // MARK: - Public

    /// Returns how many units of `to` equal 1 unit of `from`.
    func rate(from: Currency, to: Currency) async -> Double {
        if from == to { return 1.0 }
        let key = "\(from.rawValue)_\(to.rawValue)"
        if let cached = cachedRates[key], isCacheValid() { return cached }
        await fetchRates()
        return cachedRates[key] ?? fallbackRate(from: from, to: to)
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
        let url = URL(string: "https://www.bankofcanada.ca/valet/observations/FXUSDCAD/json?recent=1")!
        do {
            let response: BoCResponse = try await http.get(url)
            if let obs = response.observations.last,
               let value = obs.fxusdcad?.v,
               let rate = Double(value) {
                cachedRates["USD_CAD"] = rate
                cachedRates["CAD_USD"] = 1.0 / rate
                lastFetchedAt = Date()
            }
        } catch {
            // Silently fall back to cached or hardcoded rate
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
