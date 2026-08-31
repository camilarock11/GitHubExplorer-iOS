import Foundation

protocol SearchUsersUseCaseProtocol {
    func execute(
        query: String,
        options: UserSearchOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage
}

struct SearchUsersUseCase: SearchUsersUseCaseProtocol {
    private let repository: GitHubUserRepository

    init(repository: GitHubUserRepository) {
        self.repository = repository
    }

    func execute(
        query: String,
        options: UserSearchOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return UserSearchPage(users: [], totalCount: 0, page: page, perPage: perPage)
        }

        return try await repository.searchUsers(
            query: normalizedQuery,
            options: options,
            page: page,
            perPage: perPage
        )
    }
}

protocol FetchUserProfileUseCaseProtocol {
    func execute(login: String) async throws -> GitHubUserProfile
}

struct FetchUserProfileUseCase: FetchUserProfileUseCaseProtocol {
    private let repository: GitHubUserRepository

    init(repository: GitHubUserRepository) {
        self.repository = repository
    }

    func execute(login: String) async throws -> GitHubUserProfile {
        let normalizedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLogin.isEmpty else {
            throw NetworkError.invalidURL
        }

        return try await repository.fetchUserProfile(login: normalizedLogin)
    }
}
