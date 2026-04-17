import Foundation

/// Builds URLRequests for the Questrade REST API.
/// All data endpoints are relative to `apiServer` (returned after OAuth and stored in BrokerageConnection).
enum QuestradeEndpoints {

    // MARK: - OAuth (fixed URLs, not relative to apiServer)

    static let authBaseURL = "https://login.questrade.com"

    private static func makeURL(_ string: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var comps = URLComponents(string: string) else {
            throw APIError.invalidURL(string)
        }
        if let queryItems { comps.queryItems = queryItems }
        guard let url = comps.url else {
            throw APIError.invalidURL(string)
        }
        // Only allow HTTPS — prevent accidental/tampered downgrade to http://
        guard url.scheme?.lowercased() == "https" else {
            throw APIError.invalidURL(string)
        }
        return url
    }

    static func authorizeURL(clientId: String, redirectURI: String) throws -> URL {
        try makeURL("\(authBaseURL)/oauth2/authorize", queryItems: [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
        ])
    }

    static func tokenURL() throws -> URL {
        try makeURL("\(authBaseURL)/oauth2/token")
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

    /// Encodes a path segment per RFC 3986 so account/order IDs can't inject
    /// slashes or query separators into the URL.
    private static func encodePath(_ segment: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }

    static func accounts(apiServer: String) throws -> URL {
        try makeURL("\(apiServer)v1/accounts")
    }

    static func positions(apiServer: String, accountNumber: String) throws -> URL {
        try makeURL("\(apiServer)v1/accounts/\(encodePath(accountNumber))/positions")
    }

    static func balances(apiServer: String, accountNumber: String) throws -> URL {
        try makeURL("\(apiServer)v1/accounts/\(encodePath(accountNumber))/balances")
    }

    static func activities(apiServer: String, accountNumber: String, startTime: Date, endTime: Date) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try makeURL(
            "\(apiServer)v1/accounts/\(encodePath(accountNumber))/activities",
            queryItems: [
                .init(name: "startTime", value: formatter.string(from: startTime)),
                .init(name: "endTime",   value: formatter.string(from: endTime)),
            ]
        )
    }

    static func orders(apiServer: String, accountNumber: String) throws -> URL {
        try makeURL("\(apiServer)v1/accounts/\(encodePath(accountNumber))/orders")
    }

    static func order(apiServer: String, accountNumber: String, orderId: Int) throws -> URL {
        try makeURL("\(apiServer)v1/accounts/\(encodePath(accountNumber))/orders/\(orderId)")
    }

    static func symbolSearch(apiServer: String, prefix: String) throws -> URL {
        try makeURL("\(apiServer)v1/symbols/search", queryItems: [
            .init(name: "prefix", value: prefix),
        ])
    }

    // MARK: - Auth header

    static func authHeader(accessToken: String) -> [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}
