import Foundation

struct DependencyContainer {
    let apiClient: APIClient
    let userRepository: GitHubUserRepository
    let searchUsersUseCase: SearchUsersUseCaseProtocol
    let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol

    static let live: DependencyContainer = {
        let apiClient = URLSessionAPIClient()
        let repository = DefaultGitHubUserRepository(apiClient: apiClient)
        let searchUseCase = SearchUsersUseCase(repository: repository)
        let profileUseCase = FetchUserProfileUseCase(repository: repository)

        return DependencyContainer(
            apiClient: apiClient,
            userRepository: repository,
            searchUsersUseCase: searchUseCase,
            fetchUserProfileUseCase: profileUseCase
        )
    }()

    @MainActor
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchUsersUseCase: searchUsersUseCase)
    }
}
