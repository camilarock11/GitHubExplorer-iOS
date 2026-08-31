final class DefaultGitHubUserRepository: GitHubUserRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func searchUsers(
        query: String,
        options: UserSearchOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        let endpoint = GitHubEndpoint.searchUsers(
            query: query,
            sort: options.sort.apiValue,
            order: options.sort == .bestMatch ? nil : options.order.rawValue,
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

    func fetchUserProfile(login: String) async throws -> GitHubUserProfile {
        let response = try await apiClient.request(
            GitHubEndpoint.userProfile(login: login),
            as: GitHubUserProfileDTO.self
        )

        return response.toDomain()
    }

    func fetchUserRepositories(
        login: String,
        options: UserRepositoryOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserRepositoriesPage {
        let response = try await apiClient.request(
            GitHubEndpoint.userRepositories(
                login: login,
                sort: options.sort.rawValue,
                direction: options.order.rawValue,
                page: page,
                perPage: perPage
            ),
            as: [GitHubRepositoryDTO].self
        )

        return UserRepositoriesPage(
            repositories: response.map { $0.toDomain() },
            page: page,
            perPage: perPage
        )
    }

    func fetchRepositoryDetails(
        owner: String,
        name: String
    ) async throws -> GitHubRepositoryDetails {
        let response = try await apiClient.request(
            GitHubEndpoint.repositoryDetails(owner: owner, name: name),
            as: GitHubRepositoryDetailsDTO.self
        )

        return response.toDomain()
    }
}
