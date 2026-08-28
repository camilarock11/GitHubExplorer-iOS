protocol GitHubUserRepository {
    func searchUsers(
        query: String,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage
}
