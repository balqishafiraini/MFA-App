//
//  NetworkService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .invalidResponse: return "Invalid response from server."
        case .server(let code, let message): return "Server error \(code): \(message)"
        }
    }

    var isUnauthorized: Bool {
        guard case .server(401, _) = self else { return false }
        return true
    }
}

final class NetworkService {
    static let shared = NetworkService()

    let baseURL = AppConfig.backendBaseURL

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15

        session = URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(pinnedPublicKeyHash: AppConfig.pinnedPublicKeyHash),
            delegateQueue: nil
        )
    }

    // MARK: Endpoints

    func healthCheck() async throws {
        _ = try await sendReturningData(get("health"))
    }

    func register(_ body: RegisterRequest) async throws -> RegisterResponse {
        try await send(post("register", body: body))
    }

    func challenge(keyId: String) async throws -> ChallengeResponse {
        try await send(get("challenge", query: ["keyId": keyId]))
    }

    func verify(_ body: VerifyRequest) async throws -> VerifyResponse {
        try await send(post("verify", body: body))
    }

    func rotate(_ body: RotateRequest) async throws -> RotateResponse {
        try await send(post("rotate", body: body))
    }

    // MARK: Building requests

    private func get(_ path: String, query: [String: String] = [:]) throws -> URLRequest {
        URLRequest(url: try url(path, query: query))
    }

    private func post(_ path: String, body: some Encodable) throws -> URLRequest {
        var request = URLRequest(url: try url(path, query: [:]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func url(_ path: String, query: [String: String]) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        components.queryItems = query.isEmpty ? nil : query.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else { throw NetworkError.invalidURL }
        return url
    }

    // MARK: Sending

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data = try await sendReturningData(request)
        return try decoder.decode(Response.self, from: data)
    }

    private func sendReturningData(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                throw NetworkError.server(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }

            log(request, outcome: "\(http.statusCode)", body: data)
            return data
        } catch {
            log(request, outcome: "FAILED: \(error.localizedDescription)", body: nil)
            throw error
        }
    }

    private func log(_ request: URLRequest, outcome: String, body: Data?) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "?"
        print("[Network] \(method) \(url) -> \(outcome)")

        if let requestBody = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
            print("[Network]   request: \(requestBody)")
        }
        if let responseBody = body.flatMap({ String(data: $0, encoding: .utf8) }) {
            print("[Network]   response: \(responseBody)")
        }
        #endif
    }
}
