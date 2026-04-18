import Foundation
import Network

/// Tiny single-shot HTTP server used to receive an OAuth redirect on 127.0.0.1.
///
/// Desktop OAuth providers that won't accept custom-scheme redirects (like
/// Questrade) instead expect an http://127.0.0.1:<port>/... callback. We open
/// the auth URL in the user's default browser, the provider redirects back to
/// us here, we parse the `code` out of the query string, respond with a tiny
/// HTML "you can close this tab" page, and shut the listener down.
///
/// Security posture:
///   - Bound to 127.0.0.1 only (loopback), never exposed on a network interface.
///   - Single-request lifetime: accepts the first complete GET, then closes.
///   - `state` parameter is verified to block cross-session redirect injection.
///   - Hard 5-minute timeout so a stray listener can't linger if the user bails.
actor LoopbackOAuthReceiver {

    /// Fixed port so users only have to register one callback URL at the
    /// provider. 53682 is the de-facto "OAuth loopback" port used by rclone
    /// and others; collisions are rare on a personal Mac.
    static let port: UInt16 = 53682

    static var callbackURL: String { "http://127.0.0.1:\(port)/oauth/questrade" }

    enum ReceiverError: Error, LocalizedError {
        case listenerFailed(String)
        case timeout
        case stateMismatch
        case missingCode(String?)      // associated value = error param if present
        case cancelled

        var errorDescription: String? {
            switch self {
            case .listenerFailed(let m): return "Local OAuth listener failed: \(m)"
            case .timeout:               return "Timed out waiting for browser redirect."
            case .stateMismatch:         return "OAuth state mismatch — aborted to prevent redirect injection."
            case .missingCode(let err):  return "Authorization failed: \(err ?? "no code in redirect")"
            case .cancelled:             return "OAuth cancelled."
            }
        }
    }

    /// Waits for the provider's redirect and returns the `code` parameter.
    /// Throws on timeout (default 5 min), state mismatch, or provider-returned error.
    ///
    /// - Parameter expectedState: the same random `state` value embedded in the
    ///   authorize URL. Required — pass `nil` only if the provider doesn't
    ///   support state (Questrade does).
    func waitForCode(expectedState: String?, timeout: TimeInterval = 300) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let resumeLock = NSLock()
            func resume(_ result: Result<String, Error>) {
                resumeLock.lock(); defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let params = NWParameters.tcp
            params.requiredInterfaceType = .loopback  // refuse connections from non-loopback interfaces
            params.allowLocalEndpointReuse = true

            let listener: NWListener
            do {
                listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            } catch {
                resume(.failure(ReceiverError.listenerFailed(error.localizedDescription)))
                return
            }

            let queue = DispatchQueue(label: "com.passivmac.oauth.loopback")

            listener.stateUpdateHandler = { state in
                if case .failed(let err) = state {
                    listener.cancel()
                    resume(.failure(ReceiverError.listenerFailed(err.localizedDescription)))
                }
            }

            listener.newConnectionHandler = { connection in
                connection.start(queue: queue)
                // Read a single HTTP request (up to 8 KB is plenty for a redirect).
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8 * 1024) { data, _, _, _ in
                    defer { connection.cancel() }
                    guard let data, let request = String(data: data, encoding: .utf8) else {
                        Self.send(connection: connection, status: "400 Bad Request", body: "Bad Request")
                        return
                    }
                    // First line is "GET /oauth/questrade?code=...&state=... HTTP/1.1"
                    guard let firstLine = request.components(separatedBy: "\r\n").first,
                          let pathAndQuery = firstLine.components(separatedBy: " ").dropFirst().first,
                          let comps = URLComponents(string: "http://127.0.0.1\(pathAndQuery)") else {
                        Self.send(connection: connection, status: "400 Bad Request", body: "Bad Request")
                        return
                    }
                    let items = comps.queryItems ?? []
                    let code = items.first(where: { $0.name == "code" })?.value
                    let state = items.first(where: { $0.name == "state" })?.value
                    let oauthError = items.first(where: { $0.name == "error" })?.value

                    if let expected = expectedState, state != expected {
                        Self.send(connection: connection, status: "400 Bad Request",
                                  body: Self.errorPage(title: "State mismatch",
                                                       detail: "The OAuth state did not match. You can close this tab."))
                        listener.cancel()
                        resume(.failure(ReceiverError.stateMismatch))
                        return
                    }

                    if let code, !code.isEmpty {
                        Self.send(connection: connection, status: "200 OK",
                                  body: Self.successPage())
                        listener.cancel()
                        resume(.success(code))
                    } else {
                        Self.send(connection: connection, status: "400 Bad Request",
                                  body: Self.errorPage(title: "Authorization failed",
                                                       detail: oauthError ?? "No code returned."))
                        listener.cancel()
                        resume(.failure(ReceiverError.missingCode(oauthError)))
                    }
                }
            }

            listener.start(queue: queue)

            // Safety net: don't let a browser-never-redirected flow hang forever.
            queue.asyncAfter(deadline: .now() + timeout) {
                listener.cancel()
                resume(.failure(ReceiverError.timeout))
            }
        }
    }

    // MARK: - HTTP response helpers

    private static func send(connection: NWConnection, status: String, body: String) {
        let html = body
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func successPage() -> String {
        """
        <!doctype html><meta charset="utf-8"><title>PassivMac</title>
        <style>body{font:15px -apple-system,sans-serif;max-width:420px;margin:80px auto;color:#222;text-align:center}
        h1{font-size:20px;margin:0 0 8px}p{color:#666}</style>
        <h1>✓ Connected to PassivMac</h1>
        <p>You can close this tab and return to the app.</p>
        """
    }

    private static func errorPage(title: String, detail: String) -> String {
        """
        <!doctype html><meta charset="utf-8"><title>PassivMac</title>
        <style>body{font:15px -apple-system,sans-serif;max-width:420px;margin:80px auto;color:#222;text-align:center}
        h1{font-size:20px;margin:0 0 8px;color:#c00}p{color:#666}</style>
        <h1>\(title)</h1><p>\(detail)</p>
        """
    }
}
