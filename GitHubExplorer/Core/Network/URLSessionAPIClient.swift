import Foundation

final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }

    func request<Response: Decodable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response {
        let request = try endpoint.makeURLRequest()

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw NetworkError.unauthorized
            case 403:
                let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining")
                throw remaining == "0" ? NetworkError.rateLimited : NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 500...599:
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            default:
                throw NetworkError.invalidResponse
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw NetworkError.decodingFailed
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
    }
}
