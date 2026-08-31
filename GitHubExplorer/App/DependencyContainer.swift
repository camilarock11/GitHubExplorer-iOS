import Foundation

struct DependencyContainer {
    let apiClient: APIClient
    let userRepository: GitHubUserRepository
    let searchUsersUseCase: SearchUsersUseCaseProtocol
    let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    let fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol

    static let live: DependencyContainer = {
        let apiClient = URLSessionAPIClient()
        let repository = DefaultGitHubUserRepository(apiClient: apiClient)
        let searchUseCase = SearchUsersUseCase(repository: repository)
        let profileUseCase = FetchUserProfileUseCase(repository: repository)
        let repositoriesUseCase = FetchUserRepositoriesUseCase(repository: repository)
        let repositoryDetailsUseCase = FetchRepositoryDetailsUseCase(repository: repository)

        return DependencyContainer(
            apiClient: apiClient,
            userRepository: repository,
            searchUsersUseCase: searchUseCase,
            fetchUserProfileUseCase: profileUseCase,
            fetchUserRepositoriesUseCase: repositoriesUseCase,
            fetchRepositoryDetailsUseCase: repositoryDetailsUseCase
        )
    }()

    @MainActor
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchUsersUseCase: searchUsersUseCase)
    }
}
