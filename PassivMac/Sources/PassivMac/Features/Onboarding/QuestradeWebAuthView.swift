import SwiftUI
import WebKit

/// Embedded WKWebView that hosts the Questrade OAuth login page and
/// intercepts the redirect without actually loading it.
///
/// Questrade's developer portal rejects both custom URL schemes and loopback
/// IPs as callback URLs, so we can't use ASWebAuthenticationSession or a local
/// HTTP listener. Questrade's own docs suggest native apps use an embedded
/// webview that watches for navigation to the registered callback and extracts
/// the authorization code from the URL. That's what this view does.
///
/// Callback URL registered at Questrade: `https://www.example.com/oauth/questrade`
/// (an IANA-reserved example domain — the webview never actually navigates
/// there; we cancel the load as soon as we see the URL start with it.)
///
/// Privacy/security posture:
///   - Uses a **non-persistent** WKWebsiteDataStore so Questrade cookies
///     don't leak into the app's other networking and aren't persisted.
///   - State parameter is verified on the redirect to block cross-session
///     injection.
struct QuestradeWebAuthView: NSViewRepresentable {

    let authURL: URL
    let redirectPrefix: String
    let expectedState: String
    var onResult: (Result<String, Error>) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Ephemeral cookies — the webview's login session lives only for
        // this flow and is discarded when the view is torn down.
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: authURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            redirectPrefix: redirectPrefix,
            expectedState: expectedState,
            onResult: onResult
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let redirectPrefix: String
        let expectedState: String
        let onResult: (Result<String, Error>) -> Void
        private var didFinish = false

        init(redirectPrefix: String, expectedState: String, onResult: @escaping (Result<String, Error>) -> Void) {
            self.redirectPrefix = redirectPrefix
            self.expectedState = expectedState
            self.onResult = onResult
        }

        /// Intercept every navigation. If it's heading to our registered
        /// callback URL, cancel the load and finish the flow.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }

            // Only short-circuit on the callback URL. Let the user navigate
            // the Questrade login/approval pages freely up to that point.
            guard url.absoluteString.hasPrefix(redirectPrefix) else {
                decisionHandler(.allow); return
            }

            // From here on, cancel the load regardless of outcome — we never
            // want the webview to actually hit the placeholder redirect host.
            decisionHandler(.cancel)
            guard !didFinish else { return }
            didFinish = true

            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let err = items.first(where: { $0.name == "error" })?.value {
                onResult(.failure(APIError.brokerageError("Questrade returned error: \(err)")))
                return
            }
            let state = items.first(where: { $0.name == "state" })?.value
            guard state == expectedState else {
                onResult(.failure(APIError.brokerageError(
                    "OAuth state mismatch — aborted to prevent redirect injection."
                )))
                return
            }
            guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
                onResult(.failure(APIError.brokerageError("No authorization code in redirect.")))
                return
            }
            onResult(.success(code))
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !didFinish else { return }
            didFinish = true
            onResult(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Ignore the cancelled load we ourselves cancelled for the callback URL.
            let nsErr = error as NSError
            if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled { return }
            guard !didFinish else { return }
            didFinish = true
            onResult(.failure(error))
        }
    }
}
