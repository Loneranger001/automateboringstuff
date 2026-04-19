import Foundation

/// Builds the Questrade OAuth authorize URL and performs the code→token
/// exchange. The actual browser-side login happens in a WKWebView hosted by
/// `QuestradeWebAuthView` — Questrade's developer portal won't accept custom
/// schemes or loopback IPs, so we register an IANA-reserved example domain
/// as the callback and intercept the redirect inside an embedded webview
/// (the approach Questrade's own docs recommend for native apps).
///
/// Setup at https://www.questrade.com/api/home:
///   Callback URL: https://www.example.com/oauth/questrade
@MainActor
final class QuestradeOAuthCoordinator {

    /// Registered at Questrade. The webview never actually loads this URL —
    /// it intercepts the navigation and extracts `?code=...&state=...`.
    /// example.com is IANA-reserved so there's no risk of it ever resolving
    /// to a third-party server.
    static let redirectURI = "https://www.example.com/oauth/questrade"

    /// Random state value that both sides verify. Fresh per authorization.
    let state: String = UUID().uuidString

    /// Build the Questrade authorize URL for the embedded webview to load.
    func authorizeURL(clientId: String) throws -> URL {
        try QuestradeEndpoints.authorizeURL(
            clientId: clientId,
            redirectURI: Self.redirectURI,
            state: state
        )
    }

    /// Exchange the authorization code for access + refresh tokens.
    func exchangeCode(_ code: String, httpClient: HTTPClient) async throws -> QuestradeTokenResponse {
        let params = QuestradeEndpoints.tokenExchangeParams(code: code, redirectURI: Self.redirectURI)
        return try await httpClient.postForm(try QuestradeEndpoints.tokenURL(), formParams: params)
    }
}
