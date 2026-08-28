import Foundation

enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(statusCode: Int)
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unauthorized:
            return "This request requires authentication."
        case .forbidden:
            return "GitHub refused this request."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimited:
            return "GitHub API rate limit reached. Try again later."
        case let .serverError(statusCode):
            return "GitHub returned server error \(statusCode)."
        case .decodingFailed:
            return "The app could not read GitHub's response."
        case let .transport(message):
            return message
        }
    }
}
