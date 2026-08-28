import XCTest
@testable import GitHubExplorer

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testSearch_whenUseCaseSucceeds_publishesUsers() async {
        let user = makeUser(id: 1, login: "octocat")
        let page = UserSearchPage(users: [user], totalCount: 1, page: 1, perPage: 20)
        let useCase = MockSearchUsersUseCase(result: .success(page))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "octocat"

        viewModel.search()
        await waitUntil { viewModel.state == .loaded }

        XCTAssertEqual(viewModel.users, [user])
        XCTAssertEqual(useCase.receivedQueries, ["octocat"])
        XCTAssertEqual(useCase.receivedPages, [1])
    }

    func testSearch_whenUseCaseReturnsNoUsers_publishesEmptyState() async {
        let page = UserSearchPage(users: [], totalCount: 0, page: 1, perPage: 20)
        let useCase = MockSearchUsersUseCase(result: .success(page))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "definitely-no-user"

        viewModel.search()
        await waitUntil { viewModel.state == .empty }

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertTrue(viewModel.users.isEmpty)
    }

    func testSearch_whenUseCaseFails_publishesErrorState() async {
        let useCase = MockSearchUsersUseCase(
            result: .failure(NetworkError.rateLimited)
        )
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "octocat"

        viewModel.search()
        await waitUntil {
            if case .failed = viewModel.state { return true }
            return false
        }

        guard case let .failed(message) = viewModel.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertTrue(message.contains("rate limit"))
    }

    func testPagination_whenQueryFieldChanges_keepsUsingActiveSearchQuery() async {
        let firstUser = makeUser(id: 1, login: "apple-user")
        let firstPage = UserSearchPage(
            users: [firstUser],
            totalCount: 40,
            page: 1,
            perPage: 20
        )
        let useCase = MockSearchUsersUseCase(result: .success(firstPage))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "apple"

        viewModel.search()
        await waitUntil { viewModel.state == .loaded }

        let secondUser = makeUser(id: 2, login: "apple-user-2")
        useCase.result = .success(
            UserSearchPage(
                users: [secondUser],
                totalCount: 40,
                page: 2,
                perPage: 20
            )
        )
        viewModel.query = "google"

        viewModel.loadNextPageIfNeeded(currentUser: firstUser)
        await waitUntil { viewModel.users.count == 2 }

        XCTAssertEqual(useCase.receivedQueries, ["apple", "apple"])
        XCTAssertEqual(useCase.receivedPages, [1, 2])
        XCTAssertEqual(viewModel.users, [firstUser, secondUser])
    }

    func testRefresh_whenQueryFieldChanges_refreshesActiveSearch() async {
        let user = makeUser(id: 1, login: "apple-user")
        let page = UserSearchPage(users: [user], totalCount: 1, page: 1, perPage: 20)
        let useCase = MockSearchUsersUseCase(result: .success(page))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "apple"

        viewModel.search()
        await waitUntil { viewModel.state == .loaded }

        viewModel.query = "google"
        await viewModel.refresh()

        XCTAssertEqual(useCase.receivedQueries, ["apple", "apple"])
        XCTAssertEqual(useCase.receivedPages, [1, 1])
    }

    func testUserSearchPage_whenTotalExceedsGitHubSearchLimit_stopsAtThousandResults() {
        let pageBeforeLimit = UserSearchPage(
            users: [],
            totalCount: 1_500,
            page: 49,
            perPage: 20
        )
        let pageAtLimit = UserSearchPage(
            users: [],
            totalCount: 1_500,
            page: 50,
            perPage: 20
        )

        XCTAssertTrue(pageBeforeLimit.hasNextPage)
        XCTAssertFalse(pageAtLimit.hasNextPage)
    }

    private func makeUser(id: Int, login: String) -> GitHubUser {
        GitHubUser(
            id: id,
            login: login,
            avatarURL: nil,
            profileURL: URL(string: "https://github.com/\(login)")
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = Date()
        while !condition(), Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(for: .milliseconds(20))
        }

        if !condition() {
            XCTFail("Timed out waiting for asynchronous condition")
        }
    }
}
