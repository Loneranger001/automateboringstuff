import Foundation
import AppKit

/// Handles the Questrade OAuth 2.0 Authorization Code flow using a loopback
/// HTTP redirect (`http://127.0.0.1:<port>/oauth/questrade`).
///
/// Questrade's developer portal doesn't allow custom URL schemes for callbacks,
/// only http/https — so we can't use ASWebAuthenticationSession + a
/// `passivapp://` scheme. Instead we:
///   1. Spin up `LoopbackOAuthReceiver` on 127.0.0.1.
///   2. Open the Questrade authorize URL in the user's default browser.
///   3. After login, Questrade redirects the browser to the loopback URL;
///      the receiver grabs the `code` and shuts down.
///
/// Setup required at https://www.questrade.com/api/home:
///   Callback URL: http://127.0.0.1:53682/oauth/questrade
@MainActor
final class QuestradeOAuthCoordinator {

    static var redirectURI: String { LoopbackOAuthReceiver.callbackURL }

    /// Opens the Questrade login page in the default browser and returns the
    /// authorization code once the browser redirects back to the loopback
    /// listener.
    func authorize(clientId: String) async throws -> String {
        // Random state — Questrade will echo it back in the redirect. We reject
        // mismatches to prevent a malicious page from feeding us a foreign code.
        let state = UUID().uuidString

        let authURL = try QuestradeEndpoints.authorizeURL(
            clientId: clientId,
            redirectURI: Self.redirectURI,
            state: state
        )

        let receiver = LoopbackOAuthReceiver()

        // Start the listener *first* so we don't race the browser redirect.
        async let code = receiver.waitForCode(expectedState: state)

        // Open in default browser. NSWorkspace.open is fire-and-forget.
        NSWorkspace.shared.open(authURL)

        return try await code
    }

    /// Exchange the authorization code for access + refresh tokens.
    func exchangeCode(_ code: String, httpClient: HTTPClient) async throws -> QuestradeTokenResponse {
        let params = QuestradeEndpoints.tokenExchangeParams(code: code, redirectURI: Self.redirectURI)
        return try await httpClient.postForm(try QuestradeEndpoints.tokenURL(), formParams: params)
    }
}
