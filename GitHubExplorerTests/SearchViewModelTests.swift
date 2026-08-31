import Foundation
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
        XCTAssertEqual(viewModel.totalCount, 1)
        XCTAssertEqual(useCase.receivedQueries, ["octocat"])
        XCTAssertEqual(useCase.receivedOptions, [.default])
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
        XCTAssertEqual(viewModel.totalCount, 0)
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
        XCTAssertEqual(useCase.receivedOptions, [.default, .default])
        XCTAssertEqual(useCase.receivedPages, [1, 2])
        XCTAssertEqual(viewModel.users, [firstUser, secondUser])
    }

    func testPagination_whenSearchOptionsChange_keepsUsingActiveOptions() async {
        let firstUser = makeUser(id: 1, login: "swift-user")
        let firstPage = UserSearchPage(
            users: [firstUser],
            totalCount: 40,
            page: 1,
            perPage: 20
        )
        let useCase = MockSearchUsersUseCase(result: .success(firstPage))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "swift"
        viewModel.sort = .followers
        viewModel.order = .descending

        viewModel.search()
        await waitUntil { viewModel.state == .loaded }

        let secondUser = makeUser(id: 2, login: "swift-user-2")
        useCase.result = .success(
            UserSearchPage(
                users: [secondUser],
                totalCount: 40,
                page: 2,
                perPage: 20
            )
        )

        viewModel.sort = .joined
        viewModel.order = .ascending
        XCTAssertTrue(viewModel.hasPendingSearchOptions)

        viewModel.loadNextPageIfNeeded(currentUser: firstUser)
        await waitUntil { viewModel.users.count == 2 }

        let activeOptions = UserSearchOptions(
            sort: .followers,
            order: .descending
        )
        XCTAssertEqual(useCase.receivedOptions, [activeOptions, activeOptions])
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
        XCTAssertEqual(useCase.receivedOptions, [.default, .default])
        XCTAssertEqual(useCase.receivedPages, [1, 1])
    }

    func testRefresh_whenSearchOptionsChange_refreshesActiveOptions() async {
        let user = makeUser(id: 1, login: "swift-user")
        let page = UserSearchPage(users: [user], totalCount: 1, page: 1, perPage: 20)
        let useCase = MockSearchUsersUseCase(result: .success(page))
        let viewModel = SearchViewModel(searchUsersUseCase: useCase)
        viewModel.query = "swift"
        viewModel.sort = .repositories
        viewModel.order = .ascending

        viewModel.search()
        await waitUntil { viewModel.state == .loaded }

        viewModel.sort = .joined
        viewModel.order = .descending
        await viewModel.refresh()

        let activeOptions = UserSearchOptions(
            sort: .repositories,
            order: .ascending
        )
        XCTAssertEqual(useCase.receivedOptions, [activeOptions, activeOptions])
        XCTAssertTrue(viewModel.hasPendingSearchOptions)
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

final class URLSessionAPIClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testSearchUsersEndpoint_whenSortSelected_addsSortAndOrderQueryItems() throws {
        let request = try GitHubEndpoint.searchUsers(
            query: "swift",
            sort: "followers",
            order: "asc",
            page: 2,
            perPage: 50
        ).makeURLRequest()

        let components = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        )
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        XCTAssertEqual(queryItems["q"], "swift")
        XCTAssertEqual(queryItems["sort"], "followers")
        XCTAssertEqual(queryItems["order"], "asc")
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["per_page"], "50")
    }

    func testSearchUsersEndpoint_whenBestMatchSelected_omitsSortAndOrder() throws {
        let request = try GitHubEndpoint.searchUsers(
            query: "swift",
            sort: nil,
            order: nil,
            page: 1,
            perPage: 20
        ).makeURLRequest()

        let components = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        )
        let names = Set((components.queryItems ?? []).map(\.name))

        XCTAssertFalse(names.contains("sort"))
        XCTAssertFalse(names.contains("order"))
    }

    func testRequest_whenResponseSucceeds_decodesPayloadAndSendsGitHubHeaders() async throws {
        var apiVersionHeader: String?
        var acceptHeader: String?

        URLProtocolStub.requestHandler = { request in
            apiVersionHeader = request.value(forHTTPHeaderField: "X-GitHub-Api-Version")
            acceptHeader = request.value(forHTTPHeaderField: "Accept")
            return (
                Self.response(for: request, statusCode: 200),
                Data("{\"value\":\"ok\"}".utf8)
            )
        }

        let client = makeClient()
        let result = try await client.request(
            GitHubEndpoint.searchUsers(
                query: "octocat",
                sort: nil,
                order: nil,
                page: 1,
                perPage: 20
            ),
            as: StubPayload.self
        )

        XCTAssertEqual(result, StubPayload(value: "ok"))
        XCTAssertEqual(apiVersionHeader, "2022-11-28")
        XCTAssertEqual(acceptHeader, "application/vnd.github+json")
    }

    func testRequest_whenResponseCannotDecode_throwsDecodingFailed() async {
        URLProtocolStub.requestHandler = { request in
            (
                Self.response(for: request, statusCode: 200),
                Data("not-json".utf8)
            )
        }

        do {
            let _: StubPayload = try await makeClient().request(
                GitHubEndpoint.searchUsers(
                    query: "octocat",
                    sort: nil,
                    order: nil,
                    page: 1,
                    perPage: 20
                ),
                as: StubPayload.self
            )
            XCTFail("Expected decoding failure")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequest_whenGitHubReturnsValidationError_preservesMessage() async {
        URLProtocolStub.requestHandler = { request in
            (
                Self.response(for: request, statusCode: 422),
                Data("{\"message\":\"Validation Failed\"}".utf8)
            )
        }

        do {
            let _: StubPayload = try await makeClient().request(
                GitHubEndpoint.searchUsers(
                    query: "octocat",
                    sort: nil,
                    order: nil,
                    page: 1,
                    perPage: 20
                ),
                as: StubPayload.self
            )
            XCTFail("Expected validation error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .validationFailed("Validation Failed"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequest_whenRateLimited_throwsRateLimited() async {
        URLProtocolStub.requestHandler = { request in
            (
                Self.response(for: request, statusCode: 429),
                Data("{\"message\":\"rate limited\"}".utf8)
            )
        }

        do {
            let _: StubPayload = try await makeClient().request(
                GitHubEndpoint.searchUsers(
                    query: "octocat",
                    sort: nil,
                    order: nil,
                    page: 1,
                    perPage: 20
                ),
                as: StubPayload.self
            )
            XCTFail("Expected rate limit error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequest_whenTransientServerError_retriesAndThenSucceeds() async throws {
        var requestCount = 0

        URLProtocolStub.requestHandler = { request in
            requestCount += 1

            if requestCount == 1 {
                return (
                    Self.response(for: request, statusCode: 503),
                    Data("{\"message\":\"temporarily unavailable\"}".utf8)
                )
            }

            return (
                Self.response(for: request, statusCode: 200),
                Data("{\"value\":\"recovered\"}".utf8)
            )
        }

        let client = makeClient(
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelayNanoseconds: 0)
        )
        let result = try await client.request(
            GitHubEndpoint.searchUsers(
                query: "octocat",
                sort: nil,
                order: nil,
                page: 1,
                perPage: 20
            ),
            as: StubPayload.self
        )

        XCTAssertEqual(result, StubPayload(value: "recovered"))
        XCTAssertEqual(requestCount, 2)
    }

    func testRequest_whenTaskIsCancelled_propagatesCancellation() async {
        URLProtocolStub.requestHandler = { request in
            Thread.sleep(forTimeInterval: 0.15)
            return (
                Self.response(for: request, statusCode: 200),
                Data("{\"value\":\"too-late\"}".utf8)
            )
        }

        let client = makeClient()
        let task = Task {
            try await client.request(
                GitHubEndpoint.searchUsers(
                    query: "octocat",
                    sort: nil,
                    order: nil,
                    page: 1,
                    perPage: 20
                ),
                as: StubPayload.self
            )
        }

        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private func makeClient(
        retryPolicy: RetryPolicy = .disabled
    ) -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]

        return URLSessionAPIClient(
            session: URLSession(configuration: configuration),
            retryPolicy: retryPolicy,
            sleep: { _ in }
        )
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int,
        headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }
}

private struct StubPayload: Decodable, Equatable {
    let value: String
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
