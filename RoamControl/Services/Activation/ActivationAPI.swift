import Foundation

protocol ActivationServing: Sendable {
    func activate(code: String, deviceID: String) async throws -> ActivationResponse
    func verify(token: String, deviceID: String) async throws -> ActivationResponse
}

enum ActivationConfiguration {
    static let productionURL = URL(string: "https://ios.iirrll.top")!

    static var baseURL: URL {
#if DEBUG
        let key = "CatGoActivationDebugBaseURL"
#else
        let key = "CatGoActivationBaseURL"
#endif
        let configured = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return configured.flatMap { URL(string: $0) } ?? productionURL
    }
}

struct ActivationAPI: ActivationServing {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = ActivationConfiguration.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func activate(code: String, deviceID: String) async throws -> ActivationResponse {
        try await request(path: "api/device/activate", body: ["code": code, "deviceId": deviceID], token: nil)
    }

    func verify(token: String, deviceID: String) async throws -> ActivationResponse {
        try await request(path: "api/device/verify", body: ["deviceId": deviceID], token: token)
    }

    private func request(path: String, body: [String: String], token: String?) async throws -> ActivationResponse {
        guard let host = baseURL.host, !host.isEmpty, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else { throw ActivationError.invalidAddress }
#if DEBUG
        guard ["http", "https"].contains(baseURL.scheme) else { throw ActivationError.invalidAddress }
#else
        guard baseURL.scheme == "https" else { throw ActivationError.invalidAddress }
#endif
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ActivationError.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: raw) else { throw ActivationError.invalidResponse }
            return date
        }
        guard (200..<300).contains(http.statusCode) else {
            struct ErrorEnvelope: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data))?.error.message ?? "授权验证失败，请稍后重试。"
            if http.statusCode == 401 && token != nil { throw DeviceAuthorizationRejected(message: message) }
            throw ActivationError.server(message)
        }
        let result = try decoder.decode(ActivationResponse.self, from: data)
        guard TimeZone(identifier: result.timezone) != nil else { throw ActivationError.invalidResponse }
        return result
    }
}

struct DeviceAuthorizationRejected: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
