import Foundation
import XCTest
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

final class MockFetchUserProfileUseCase: FetchUserProfileUseCaseProtocol {
    var result: Result<GitHubUserProfile, Error>
    private(set) var receivedLogins: [String] = []

    init(result: Result<GitHubUserProfile, Error>) {
        self.result = result
    }

    func execute(login: String) async throws -> GitHubUserProfile {
        receivedLogins.append(login)
        return try result.get()
    }
}

final class MockFetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol {
    var result: Result<UserRepositoriesPage, Error>
    private(set) var receivedLogins: [String] = []
    private(set) var receivedOptions: [UserRepositoryOptions] = []
    private(set) var receivedPages: [Int] = []

    init(result: Result<UserRepositoriesPage, Error>) {
        self.result = result
    }

    func execute(
        login: String,
        options: UserRepositoryOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserRepositoriesPage {
        receivedLogins.append(login)
        receivedOptions.append(options)
        receivedPages.append(page)
        return try result.get()
    }
}

@MainActor
final class UserProfileViewModelTests: XCTestCase {
    func testLoadIfNeeded_whenUseCaseSucceeds_publishesProfile() async {
        let profile = makeProfile()
        let useCase = MockFetchUserProfileUseCase(result: .success(profile))
        let viewModel = UserProfileViewModel(
            login: "octocat",
            fetchUserProfileUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            if case .loaded = viewModel.state { return true }
            return false
        }

        XCTAssertEqual(viewModel.state, .loaded(profile))
        XCTAssertEqual(useCase.receivedLogins, ["octocat"])
    }

    func testLoadIfNeeded_whenUseCaseFails_publishesFailure() async {
        let useCase = MockFetchUserProfileUseCase(
            result: .failure(NetworkError.notFound)
        )
        let viewModel = UserProfileViewModel(
            login: "missing-user",
            fetchUserProfileUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            if case .failed = viewModel.state { return true }
            return false
        }

        guard case let .failed(message) = viewModel.state else {
            return XCTFail("Expected failed state")
        }

        XCTAssertTrue(message.contains("not found"))
        XCTAssertEqual(useCase.receivedLogins, ["missing-user"])
    }

    func testRefresh_fetchesProfileAgain() async {
        let profile = makeProfile()
        let useCase = MockFetchUserProfileUseCase(result: .success(profile))
        let viewModel = UserProfileViewModel(
            login: "octocat",
            fetchUserProfileUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            if case .loaded = viewModel.state { return true }
            return false
        }

        await viewModel.refresh()

        XCTAssertEqual(useCase.receivedLogins, ["octocat", "octocat"])
        XCTAssertEqual(viewModel.state, .loaded(profile))
    }

    private func makeProfile() -> GitHubUserProfile {
        GitHubUserProfile(
            id: 1,
            login: "octocat",
            name: "The Octocat",
            avatarURL: URL(string: "https://avatars.githubusercontent.com/u/583231"),
            profileURL: URL(string: "https://github.com/octocat"),
            bio: "GitHub mascot",
            company: "GitHub",
            location: "San Francisco",
            websiteURL: URL(string: "https://github.blog"),
            followers: 10,
            following: 2,
            publicRepositories: 8
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
            XCTFail("Timed out waiting for profile state")
        }
    }
}

@MainActor
final class UserRepositoriesViewModelTests: XCTestCase {
    func testLoadIfNeeded_whenUseCaseSucceeds_publishesRepositories() async {
        let repository = makeRepository(id: 1, name: "Hello-World")
        let page = UserRepositoriesPage(
            repositories: [repository],
            page: 1,
            perPage: 20
        )
        let useCase = MockFetchUserRepositoriesUseCase(result: .success(page))
        let viewModel = UserRepositoriesViewModel(
            login: "octocat",
            fetchUserRepositoriesUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.state == .loaded }

        XCTAssertEqual(viewModel.repositories, [repository])
        XCTAssertEqual(useCase.receivedLogins, ["octocat"])
        XCTAssertEqual(useCase.receivedOptions, [.default])
        XCTAssertEqual(useCase.receivedPages, [1])
    }

    func testLoadIfNeeded_whenUseCaseReturnsNoRepositories_publishesEmpty() async {
        let page = UserRepositoriesPage(repositories: [], page: 1, perPage: 20)
        let useCase = MockFetchUserRepositoriesUseCase(result: .success(page))
        let viewModel = UserRepositoriesViewModel(
            login: "octocat",
            fetchUserRepositoriesUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.state == .empty }

        XCTAssertTrue(viewModel.repositories.isEmpty)
        XCTAssertEqual(viewModel.state, .empty)
    }

    func testLoadIfNeeded_whenUseCaseFails_publishesFailure() async {
        let useCase = MockFetchUserRepositoriesUseCase(
            result: .failure(NetworkError.rateLimited)
        )
        let viewModel = UserRepositoriesViewModel(
            login: "octocat",
            fetchUserRepositoriesUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            if case .failed = viewModel.state { return true }
            return false
        }

        guard case let .failed(message) = viewModel.state else {
            return XCTFail("Expected failed state")
        }

        XCTAssertTrue(message.contains("rate limit"))
    }

    func testPagination_deduplicatesRepositoriesAcrossPages() async {
        let firstPageRepositories = (1...20).map {
            makeRepository(id: $0, name: "repo-\($0)")
        }
        let firstPage = UserRepositoriesPage(
            repositories: firstPageRepositories,
            page: 1,
            perPage: 20
        )
        let useCase = MockFetchUserRepositoriesUseCase(result: .success(firstPage))
        let viewModel = UserRepositoriesViewModel(
            login: "octocat",
            fetchUserRepositoriesUseCase: useCase
        )

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.repositories.count == 20 }

        let duplicate = firstPageRepositories[19]
        let newRepository = makeRepository(id: 21, name: "repo-21")
        useCase.result = .success(
            UserRepositoriesPage(
                repositories: [duplicate, newRepository],
                page: 2,
                perPage: 20
            )
        )

        viewModel.loadNextPageIfNeeded(currentRepository: firstPageRepositories[19])
        await waitUntil { viewModel.repositories.count == 21 }

        XCTAssertEqual(Set(viewModel.repositories.map(\.id)).count, 21)
        XCTAssertEqual(useCase.receivedPages, [1, 2])
    }

    func testRefresh_whenControlsChange_keepsUsingActiveOptions() async {
        let repository = makeRepository(id: 1, name: "repo")
        let page = UserRepositoriesPage(
            repositories: [repository],
            page: 1,
            perPage: 20
        )
        let useCase = MockFetchUserRepositoriesUseCase(result: .success(page))
        let viewModel = UserRepositoriesViewModel(
            login: "octocat",
            fetchUserRepositoriesUseCase: useCase
        )
        viewModel.sort = .pushed
        viewModel.order = .ascending

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.state == .loaded }

        viewModel.sort = .created
        viewModel.order = .descending
        XCTAssertTrue(viewModel.hasPendingOptions)

        await viewModel.refresh()

        let activeOptions = UserRepositoryOptions(
            sort: .pushed,
            order: .ascending
        )
        XCTAssertEqual(useCase.receivedOptions, [activeOptions, activeOptions])
        XCTAssertTrue(viewModel.hasPendingOptions)
    }

    private func makeRepository(id: Int, name: String) -> GitHubRepository {
        GitHubRepository(
            id: id,
            name: name,
            description: "Repository \(name)",
            htmlURL: URL(string: "https://github.com/octocat/\(name)"),
            language: "Swift",
            stargazersCount: id,
            forksCount: max(0, id - 1),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id))
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
            XCTFail("Timed out waiting for repositories state")
        }
    }
}

final class GitHubUserProfileMappingTests: XCTestCase {
    func testProfileDTO_mapsGitHubResponseAndNormalizesWebsite() throws {
        let json = """
        {
          "id": 1,
          "login": "octocat",
          "name": "The Octocat",
          "avatar_url": "https://avatars.githubusercontent.com/u/583231",
          "html_url": "https://github.com/octocat",
          "bio": "GitHub mascot",
          "company": "GitHub",
          "location": "San Francisco",
          "blog": "github.blog",
          "followers": 10,
          "following": 2,
          "public_repos": 8
        }
        """

        let dto = try JSONDecoder().decode(
            GitHubUserProfileDTO.self,
            from: Data(json.utf8)
        )
        let profile = dto.toDomain()

        XCTAssertEqual(profile.login, "octocat")
        XCTAssertEqual(profile.name, "The Octocat")
        XCTAssertEqual(profile.websiteURL, URL(string: "https://github.blog"))
        XCTAssertEqual(profile.followers, 10)
        XCTAssertEqual(profile.following, 2)
        XCTAssertEqual(profile.publicRepositories, 8)
    }

    func testUserProfileEndpoint_buildsExpectedPathWithoutQueryItems() throws {
        let request = try GitHubEndpoint.userProfile(login: "octocat")
            .makeURLRequest()

        XCTAssertEqual(request.url?.path, "/users/octocat")
        XCTAssertNil(request.url?.query)
    }

    func testRepositoryDTO_mapsUsefulMetadata() throws {
        let json = """
        {
          "id": 42,
          "name": "Hello-World",
          "description": "My first repository",
          "html_url": "https://github.com/octocat/Hello-World",
          "language": "Swift",
          "stargazers_count": 80,
          "forks_count": 9,
          "updated_at": "2026-08-31T10:00:00Z"
        }
        """

        let dto = try JSONDecoder().decode(
            GitHubRepositoryDTO.self,
            from: Data(json.utf8)
        )
        let repository = dto.toDomain()

        XCTAssertEqual(repository.id, 42)
        XCTAssertEqual(repository.name, "Hello-World")
        XCTAssertEqual(repository.language, "Swift")
        XCTAssertEqual(repository.stargazersCount, 80)
        XCTAssertEqual(repository.forksCount, 9)
        XCTAssertNotNil(repository.updatedAt)
    }

    func testUserRepositoriesEndpoint_buildsPagingAndSortingQueryItems() throws {
        let request = try GitHubEndpoint.userRepositories(
            login: "octocat",
            sort: "pushed",
            direction: "asc",
            page: 2,
            perPage: 20
        ).makeURLRequest()

        XCTAssertEqual(request.url?.path, "/users/octocat/repos")

        let components = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        )
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        XCTAssertEqual(queryItems["type"], "owner")
        XCTAssertEqual(queryItems["sort"], "pushed")
        XCTAssertEqual(queryItems["direction"], "asc")
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["per_page"], "20")
    }
}
