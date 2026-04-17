import Foundation

/// Builds URLRequests for the Questrade REST API.
/// All data endpoints are relative to `apiServer` (returned after OAuth and stored in BrokerageConnection).
enum QuestradeEndpoints {

    // MARK: - OAuth (fixed URLs, not relative to apiServer)

    static let authBaseURL = "https://login.questrade.com"

    static func authorizeURL(clientId: String, redirectURI: String) -> URL {
        var comps = URLComponents(string: "\(authBaseURL)/oauth2/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
        ]
        return comps.url!
    }

    static func tokenURL() -> URL {
        URL(string: "\(authBaseURL)/oauth2/token")!
    }

    static func tokenExchangeParams(code: String, redirectURI: String) -> [String: String] {
        [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
        ]
    }

    static func tokenRefreshParams(refreshToken: String) -> [String: String] {
        [
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
        ]
    }

    // MARK: - Data endpoints (relative to apiServer)

    static func accounts(apiServer: String) -> URL {
        URL(string: "\(apiServer)v1/accounts")!
    }

    static func positions(apiServer: String, accountNumber: String) -> URL {
        URL(string: "\(apiServer)v1/accounts/\(accountNumber)/positions")!
    }

    static func balances(apiServer: String, accountNumber: String) -> URL {
        URL(string: "\(apiServer)v1/accounts/\(accountNumber)/balances")!
    }

    static func activities(apiServer: String, accountNumber: String, startTime: Date, endTime: Date) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var comps = URLComponents(string: "\(apiServer)v1/accounts/\(accountNumber)/activities")!
        comps.queryItems = [
            .init(name: "startTime", value: formatter.string(from: startTime)),
            .init(name: "endTime",   value: formatter.string(from: endTime)),
        ]
        return comps.url!
    }

    static func orders(apiServer: String, accountNumber: String) -> URL {
        URL(string: "\(apiServer)v1/accounts/\(accountNumber)/orders")!
    }

    static func order(apiServer: String, accountNumber: String, orderId: Int) -> URL {
        URL(string: "\(apiServer)v1/accounts/\(accountNumber)/orders/\(orderId)")!
    }

    static func symbolSearch(apiServer: String, prefix: String) -> URL {
        var comps = URLComponents(string: "\(apiServer)v1/symbols/search")!
        comps.queryItems = [.init(name: "prefix", value: prefix)]
        return comps.url!
    }

    // MARK: - Auth header

    static func authHeader(accessToken: String) -> [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}
