import Foundation
import AppKit

/// Handles the Questrade OAuth 2.0 Authorization Code flow using a manual
/// copy-paste redirect pattern.
///
/// Questrade's developer portal has two hard constraints that rule out an
/// automated redirect:
///   - Callback URL must be https:// (no custom schemes → no ASWebAuthenticationSession)
///   - No raw IP addresses allowed (rejects 127.0.0.1 → no loopback listener)
///
/// Running a real HTTPS loopback server would require a trusted cert on every
/// user's machine. So instead: the user registers any HTTPS URL Questrade
/// accepts (e.g. `https://localhost/oauth/questrade`), completes auth in the
/// browser, and pastes the redirected URL back into PassivMac. We extract the
/// `code` query parameter and continue.
///
/// Setup at https://www.questrade.com/api/home:
///   Callback URL: https://localhost/oauth/questrade
@MainActor
final class QuestradeOAuthCoordinator {

    static let redirectURI = "https://localhost/oauth/questrade"

    /// Opens the Questrade login page in the default browser.
    /// Returns the random `state` value the caller must verify when the user
    /// pastes back the redirect URL.
    func beginAuthorization(clientId: String) throws -> String {
        let state = UUID().uuidString
        let authURL = try QuestradeEndpoints.authorizeURL(
            clientId: clientId,
            redirectURI: Self.redirectURI,
            state: state
        )
        NSWorkspace.shared.open(authURL)
        return state
    }

    /// Parse the URL the user pasted back. Accepts either the full redirect
    /// URL (`https://localhost/oauth/questrade?code=...&state=...`) or just
    /// the query string, and returns the authorization code.
    ///
    /// - Throws: `APIError.authExpired` if no code is present or state doesn't match.
    func extractCode(fromPastedURL pasted: String, expectedState: String) throws -> String {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)

        // Accept full URL, "?code=..." fragment, or "code=..." bare query string.
        let queryString: String
        if let q = URLComponents(string: trimmed)?.query {
            queryString = q
        } else if trimmed.hasPrefix("?") {
            queryString = String(trimmed.dropFirst())
        } else {
            queryString = trimmed
        }

        var items: [URLQueryItem] = []
        var comps = URLComponents()
        comps.query = queryString
        items = comps.queryItems ?? []

        if let err = items.first(where: { $0.name == "error" })?.value {
            throw APIError.brokerageError("Questrade returned error: \(err)")
        }
        let state = items.first(where: { $0.name == "state" })?.value
        // State is required — protects against a user pasting an old/foreign redirect.
        guard state == expectedState else {
            throw APIError.brokerageError("State mismatch — paste the redirect URL from this session's browser tab.")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw APIError.brokerageError("No authorization code found in the pasted URL.")
        }
        return code
    }

    /// Exchange the authorization code for access + refresh tokens.
    func exchangeCode(_ code: String, httpClient: HTTPClient) async throws -> QuestradeTokenResponse {
        let params = QuestradeEndpoints.tokenExchangeParams(code: code, redirectURI: Self.redirectURI)
        return try await httpClient.postForm(try QuestradeEndpoints.tokenURL(), formParams: params)
    }
}
