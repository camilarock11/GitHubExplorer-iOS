protocol APIClient {
    func request<Response: Decodable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response
}
