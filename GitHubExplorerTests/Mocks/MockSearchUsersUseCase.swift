@testable import GitHubExplorer

final class MockSearchUsersUseCase: SearchUsersUseCaseProtocol {
    var result: Result<UserSearchPage, Error>
    private(set) var receivedQueries: [String] = []
    private(set) var receivedOptions: [UserSearchOptions] = []
    private(set) var receivedPages: [Int] = []

    init(result: Result<UserSearchPage, Error>) {
        self.result = result
    }

    func execute(
        query: String,
        options: UserSearchOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage {
        receivedQueries.append(query)
        receivedOptions.append(options)
        receivedPages.append(page)
        return try result.get()
    }
}
