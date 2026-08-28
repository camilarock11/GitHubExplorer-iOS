import Foundation

struct RetryPolicy: Equatable {
    let maxAttempts: Int
    let baseDelayNanoseconds: UInt64

    init(
        maxAttempts: Int = 3,
        baseDelayNanoseconds: UInt64 = 200_000_000
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelayNanoseconds = baseDelayNanoseconds
    }

    static let `default` = RetryPolicy()
    static let disabled = RetryPolicy(maxAttempts: 1, baseDelayNanoseconds: 0)

    func shouldRetry(statusCode: Int, method: String?) -> Bool {
        guard method == HTTPMethod.get.rawValue else { return false }
        return statusCode == 429 || (500...599).contains(statusCode)
    }

    func shouldRetry(urlError: URLError, method: String?) -> Bool {
        guard method == HTTPMethod.get.rawValue else { return false }

        let retryableCodes: Set<URLError.Code> = [
            .timedOut,
            .networkConnectionLost,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed
        ]
        return retryableCodes.contains(urlError.code)
    }

    func delayNanoseconds(afterFailedAttempt attempt: Int) -> UInt64 {
        guard baseDelayNanoseconds > 0 else { return 0 }
        let exponent = max(0, min(attempt - 1, 8))
        let multiplier = UInt64(1 << exponent)
        return baseDelayNanoseconds * multiplier
    }
}

final class URLSessionAPIClient: APIClient {
    typealias Sleep = (UInt64) async throws -> Void

    private let session: URLSession
    private let decoder: JSONDecoder
    private let retryPolicy: RetryPolicy
    private let sleep: Sleep

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        retryPolicy: RetryPolicy = .default,
        sleep: @escaping Sleep = { nanoseconds in
            guard nanoseconds > 0 else { return }
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.session = session
        self.decoder = decoder
        self.retryPolicy = retryPolicy
        self.sleep = sleep
    }

    func request<Response: Decodable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response {
        let request = try endpoint.makeURLRequest()
        var attempt = 1

        while true {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                if (200...299).contains(httpResponse.statusCode) {
                    return try decode(type, from: data)
                }

                if attempt < retryPolicy.maxAttempts,
                   retryPolicy.shouldRetry(
                    statusCode: httpResponse.statusCode,
                    method: request.httpMethod
                   ) {
                    try await waitBeforeRetry(afterFailedAttempt: attempt)
                    attempt += 1
                    continue
                }

                throw mapHTTPError(response: httpResponse, data: data)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError {
                if error.code == .cancelled || Task.isCancelled {
                    throw CancellationError()
                }

                if attempt < retryPolicy.maxAttempts,
                   retryPolicy.shouldRetry(
                    urlError: error,
                    method: request.httpMethod
                   ) {
                    try await waitBeforeRetry(afterFailedAttempt: attempt)
                    attempt += 1
                    continue
                }

                throw NetworkError.transport(error.localizedDescription)
            } catch let error as NetworkError {
                throw error
            } catch {
                if Task.isCancelled {
                    throw CancellationError()
                }
                throw NetworkError.transport(error.localizedDescription)
            }
        }
    }

    private func decode<Response: Decodable>(
        _ type: Response.Type,
        from data: Data
    ) throws -> Response {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    private func waitBeforeRetry(afterFailedAttempt attempt: Int) async throws {
        try Task.checkCancellation()
        try await sleep(retryPolicy.delayNanoseconds(afterFailedAttempt: attempt))
        try Task.checkCancellation()
    }

    private func mapHTTPError(
        response: HTTPURLResponse,
        data: Data
    ) -> NetworkError {
        switch response.statusCode {
        case 401:
            return .unauthorized
        case 403:
            let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
            return remaining == "0" ? .rateLimited : .forbidden
        case 404:
            return .notFound
        case 422:
            return .validationFailed(gitHubErrorMessage(from: data))
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(statusCode: response.statusCode)
        default:
            return .invalidResponse
        }
    }

    private func gitHubErrorMessage(from data: Data) -> String? {
        try? decoder.decode(GitHubAPIErrorResponse.self, from: data).message
    }
}

private struct GitHubAPIErrorResponse: Decodable {
    let message: String?
}
