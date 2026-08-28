final class DefaultGitHubUserRepository: GitHubUserRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func searchUsers(
        query: String,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        let endpoint = GitHubEndpoint.searchUsers(
            query: query,
            page: page,
            perPage: perPage
        )

        let response = try await apiClient.request(
            endpoint,
            as: SearchUsersResponseDTO.self
        )

        return UserSearchPage(
            users: response.items.map { $0.toDomain() },
            totalCount: response.totalCount,
            page: page,
            perPage: perPage
        )
    }
}
