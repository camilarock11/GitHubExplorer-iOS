import Foundation

protocol SearchUsersUseCaseProtocol {
    func execute(
        query: String,
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
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return UserSearchPage(users: [], totalCount: 0, page: page, perPage: perPage)
        }

        return try await repository.searchUsers(
            query: normalizedQuery,
            page: page,
            perPage: perPage
        )
    }
}
