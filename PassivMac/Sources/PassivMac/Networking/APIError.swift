import Foundation

enum APIError: LocalizedError {
    case invalidURL(String)
    case noData
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case authExpired
    case rateLimited(retryAfter: TimeInterval?)
    case networkUnavailable
    case brokerageError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noData:
            return "No data received from server."
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .decodingError(let err):
            return "Failed to decode response: \(err.localizedDescription)"
        case .authExpired:
            return "Authentication expired. Please reconnect your brokerage account."
        case .rateLimited(let retry):
            if let retry {
                return "Rate limited. Retry after \(Int(retry))s."
            }
            return "Rate limited by brokerage API."
        case .networkUnavailable:
            return "No network connection."
        case .brokerageError(let msg):
            return "Brokerage error: \(msg)"
        }
    }
}
