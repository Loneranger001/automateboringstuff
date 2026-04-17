import Foundation
import AuthenticationServices

/// Handles the Questrade OAuth 2.0 Authorization Code flow using ASWebAuthenticationSession.
///
/// Setup required:
///   1. Register an app at https://www.questrade.com/api/home to get a clientId.
///   2. Set redirect URI to "passivapp://oauth/questrade" in the Questrade developer portal.
///   3. Add CFBundleURLTypes entry for scheme "passivapp" in Info.plist (or Package manifest).
@MainActor
final class QuestradeOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {

    static let redirectURI = "passivapp://oauth/questrade"
    static let callbackScheme = "passivapp"

    private weak var presentationAnchor: NSWindow?

    init(presentationAnchor: NSWindow? = nil) {
        self.presentationAnchor = presentationAnchor
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Safe to call on main thread — ASWebAuthenticationSession always calls this on main
        DispatchQueue.main.sync {
            self.presentationAnchor ?? NSApp.keyWindow ?? NSWindow()
        }
    }

    // MARK: - Public

    /// Opens the Questrade login page and returns the authorization code on success.
    func authorize(clientId: String) async throws -> String {
        let authURL = QuestradeEndpoints.authorizeURL(
            clientId: clientId,
            redirectURI: Self.redirectURI
        )

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    // User cancelled returns ASWebAuthenticationSessionError.canceledLogin
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let callbackURL,
                    let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?
                        .value
                else {
                    continuation.resume(throwing: APIError.authExpired)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    /// Exchange the authorization code for access + refresh tokens.
    func exchangeCode(_ code: String, httpClient: HTTPClient) async throws -> QuestradeTokenResponse {
        let params = QuestradeEndpoints.tokenExchangeParams(code: code, redirectURI: Self.redirectURI)
        return try await httpClient.postForm(QuestradeEndpoints.tokenURL(), formParams: params)
    }
}
