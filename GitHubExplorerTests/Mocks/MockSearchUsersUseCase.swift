@testable import GitHubExplorer

final class MockSearchUsersUseCase: SearchUsersUseCaseProtocol {
    var result: Result<UserSearchPage, Error>
    private(set) var receivedQueries: [String] = []
    private(set) var receivedPages: [Int] = []

    init(result: Result<UserSearchPage, Error>) {
        self.result = result
    }

    func execute(
        query: String,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        receivedQueries.append(query)
        receivedPages.append(page)
        return try result.get()
    }
}
