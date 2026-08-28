import Foundation

struct DependencyContainer {
    let apiClient: APIClient
    let userRepository: GitHubUserRepository
    let searchUsersUseCase: SearchUsersUseCaseProtocol

    static let live: DependencyContainer = {
        let apiClient = URLSessionAPIClient()
        let repository = DefaultGitHubUserRepository(apiClient: apiClient)
        let useCase = SearchUsersUseCase(repository: repository)

        return DependencyContainer(
            apiClient: apiClient,
            userRepository: repository,
            searchUsersUseCase: useCase
        )
    }()

    @MainActor
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchUsersUseCase: searchUsersUseCase)
    }
}
