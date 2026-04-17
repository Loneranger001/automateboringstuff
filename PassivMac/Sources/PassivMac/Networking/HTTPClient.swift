import Foundation

/// Thin URLSession wrapper with async/await, JSON decoding, and error mapping.
actor HTTPClient {

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
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
            .map { "\($0.key)=\(urlEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await perform(request)
    }

    // MARK: - DELETE

    func delete(_ url: URL, headers: [String: String] = [:]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: Data())
    }

    // MARK: - Private

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw APIError.networkUnavailable
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
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
