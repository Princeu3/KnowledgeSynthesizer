import Foundation

/// Communicates with the FastAPI backend for content extraction and enrichment
actor APIService {
    static let shared = APIService()

    // TODO: Replace with your actual backend URL once deployed
    private let baseURL: String

    private let session: URLSession

    init(baseURL: String = "http://localhost:8000") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Instagram Extraction

    struct InstagramExtractionResult: Codable {
        let title: String
        let content: String
        let thumbnailURL: String?
        let visionAnalysis: String?
        let topics: [String]
        let entities: [String]
        let category: String?
        let contentDate: String?
        let metadata: [String: String]?
    }

    func extractInstagram(url: String) async throws -> InstagramExtractionResult {
        let body: [String: Any] = ["url": url]
        return try await post(endpoint: "/api/extract/instagram", body: body)
    }

    // MARK: - Generic Extraction

    struct ExtractionResult: Codable {
        let title: String
        let content: String
        let thumbnailURL: String?
        let topics: [String]
        let entities: [String]
        let category: String?
    }

    func extract(url: String, sourceType: String) async throws -> ExtractionResult {
        let body: [String: Any] = [
            "url": url,
            "source_type": sourceType
        ]
        return try await post(endpoint: "/api/extract", body: body)
    }

    // MARK: - Health Check

    struct HealthResponse: Codable {
        let status: String
    }

    func healthCheck() async throws -> HealthResponse {
        return try await get(endpoint: "/health")
    }

    // MARK: - HTTP Helpers

    private func get<T: Codable>(endpoint: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Codable>(endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (HTTP \(code))"
        }
    }
}
