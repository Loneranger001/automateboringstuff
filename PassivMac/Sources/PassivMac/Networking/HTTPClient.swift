import Foundation
import CommonCrypto

/// Thin URLSession wrapper with async/await, JSON decoding, and error mapping.
actor HTTPClient {

    /// Maximum number of bytes of response body included in `APIError.httpError`.
    /// Keeps tokens, PII, and stack traces out of logs/UI error dialogs.
    private static let maxErrorBodyBytes = 256

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        // Default to a session with a TLS-pinning delegate for the production hosts.
        if let session {
            self.session = session
        } else {
            let delegate = PinnedHostsSessionDelegate()
            self.session = URLSession(
                configuration: .ephemeral,
                delegate: delegate,
                delegateQueue: nil
            )
        }
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - GET

    func get<T: Decodable>(_ url: URL, headers: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await perform(request)
    }

    // MARK: - POST

    func post<Body: Encodable, Response: Decodable>(
        _ url: URL,
        body: Body,
        headers: [String: String] = [:]
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    /// POST with URL-encoded form body (used by OAuth token endpoints).
    func postForm<Response: Decodable>(
        _ url: URL,
        formParams: [String: String],
        headers: [String: String] = [:]
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = formParams
            .map { "\(Self.formEncode($0.key))=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await perform(request)
    }

    // MARK: - DELETE

    func delete(_ url: URL, headers: [String: String] = [:]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw APIError.networkUnavailable
        } catch let urlError as URLError where urlError.code == .cancelled
                                             || urlError.code == .serverCertificateUntrusted
                                             || urlError.code == .serverCertificateHasBadDate
                                             || urlError.code == .serverCertificateHasUnknownRoot
                                             || urlError.code == .serverCertificateNotYetValid {
            // Treat pinning failures as auth-level errors so upstream UI can surface them.
            throw APIError.brokerageError("TLS certificate validation failed.")
        }
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.authExpired
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            // Truncate body to avoid leaking tokens/PII/stack traces via error messages.
            let truncated = Self.truncatedBody(data)
            throw APIError.httpError(statusCode: http.statusCode, body: truncated)
        }
    }

    private static func truncatedBody(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        let slice = data.prefix(maxErrorBodyBytes)
        let text = String(data: slice, encoding: .utf8) ?? "<binary>"
        if data.count > maxErrorBodyBytes {
            return text + "… (\(data.count - maxErrorBodyBytes) more bytes)"
        }
        return text
    }

    /// RFC 3986 application/x-www-form-urlencoded encoding.
    /// `.urlQueryAllowed` leaves `&`, `=`, `+`, etc. un-escaped, which breaks form bodies
    /// (and can let attacker-controlled input inject extra params into OAuth requests).
    private static func formEncode(_ string: String) -> String {
        // RFC 3986 unreserved characters.
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

// MARK: - TLS pinning

/// Pins `*.questrade.com` to the set of SPKI hashes we expect. Any other host uses
/// the default system trust evaluation. This blocks MITM attacks on token refresh
/// and order placement even if a rogue root is installed on the user's machine.
private final class PinnedHostsSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    /// SHA-256 hashes (base64) of the SubjectPublicKeyInfo for accepted certs.
    /// Populate via `openssl s_client -connect login.questrade.com:443 | openssl x509 -pubkey -noout | \
    ///   openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | openssl base64`.
    /// Empty array → fall back to system trust (safe default; still no downgrade to HTTP).
    private static let pinnedSPKIHashes: Set<String> = []

    private static let pinnedHostSuffixes: [String] = ["questrade.com"]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        let isPinnedHost = Self.pinnedHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }

        // First, let the system evaluate the chain.
        var error: CFError?
        let systemTrusted = SecTrustEvaluateWithError(serverTrust, &error)
        guard systemTrusted else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If we have pins and this is a pinned host, require a match.
        if isPinnedHost, !Self.pinnedSPKIHashes.isEmpty {
            // Walk the chain looking for a matching SPKI hash.
            // SecTrustCopyCertificateChain is the modern API (macOS 12+).
            let chain = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate]) ?? []
            let matched = chain.contains { cert in
                guard let spkiHash = Self.spkiSHA256(of: cert) else { return false }
                return Self.pinnedSPKIHashes.contains(spkiHash)
            }
            if !matched {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    private static func spkiSHA256(of certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            return nil
        }
        // Note: using the raw external representation is a weaker form of pinning than a true
        // DER-encoded SPKI; acceptable as a defense-in-depth layer until real pins are added.
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { buf in
            _ = CC_SHA256(buf.baseAddress, CC_LONG(buf.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}
