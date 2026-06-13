import Foundation

enum HTTPMethod: String {
    case get = "GET"
}

struct APIRequest {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var timeout: TimeInterval?
}

struct APIMeta: Codable, Hashable {
    var count: Int?
    var total: Int?
    var limit: Int?
    var offset: Int?
    var updatedCount: Int?
    var deletedCount: Int?
    var dataVersion: String?
    var lastUpdated: Date?
    var serverTime: Date?
    var source: String?
}

struct APIResponseErrorBody: Decodable, Hashable {
    var code: String
    var message: String
    var details: [String]
}

struct APIResponse<T: Decodable>: Decodable {
    var data: T?
    var meta: APIMeta?
    var error: APIResponseErrorBody?
}

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case timeout
    case serverError(statusCode: Int, code: String, message: String, details: [String])
    case decodingFailed(Error)
    case validationFailed([String])
    case noData
    case offline
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out."
        case let .serverError(_, code, message, details):
            return ([message, code] + details).filter { !$0.isEmpty }.joined(separator: " · ")
        case .decodingFailed(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        case .validationFailed(let details):
            return "Invalid event data: \(details.joined(separator: "; "))"
        case .noData:
            return "Server response did not include data."
        case .offline:
            return "Network appears to be offline."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

final class NetworkClient {
    private let baseURL: URL
    private let session: URLSession
    private let timeout: TimeInterval
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        timeout: TimeInterval = 8
    ) {
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<T: Decodable>(_ request: APIRequest, as type: T.Type = T.self) async throws -> APIResponse<T> {
        let url = try url(for: request)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout ?? timeout

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.requestFailed(URLError(.badServerResponse))
            }

            let decoded = try decode(APIResponse<T>.self, from: data)
            if let error = decoded.error {
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    code: error.code,
                    message: error.message,
                    details: error.details
                )
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    code: "HTTP_\(httpResponse.statusCode)",
                    message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    details: []
                )
            }

            return decoded
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(error)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw APIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
                throw APIError.offline
            default:
                throw APIError.requestFailed(error)
            }
        } catch {
            throw APIError.unknown(error)
        }
    }

    private func url(for request: APIRequest) throws -> URL {
        var normalizedPath = request.path
        if normalizedPath.hasPrefix("/") {
            normalizedPath.removeFirst()
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(normalizedPath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return url
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}
