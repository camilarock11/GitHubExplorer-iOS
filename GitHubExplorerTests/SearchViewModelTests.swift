import XCTest
@testable import GitHubExplorer

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testSearch_whenUseCaseSucceeds_publishesUsers() async {
        let user = GitHubUser(
            id: 1,
            login: "octocat",
            avatarURL: nil,
            profileURL: URL(string: "https://github.com/octocat")
        )
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

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = Date()
        while !condition(), Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
