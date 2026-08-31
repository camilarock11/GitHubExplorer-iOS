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
}
