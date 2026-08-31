import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var sort: UserSearchSort = .bestMatch
    @Published var order: UserSearchOrder = .descending
    @Published private(set) var users: [GitHubUser] = []
    @Published private(set) var state: SearchViewState = .idle
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var totalCount = 0

    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let pageSize = 20
    private var currentPage = 0
    private var canLoadMore = false
    private var activeQuery = ""
    private var activeOptions: UserSearchOptions = .default
    private var activeTask: Task<Void, Never>?

    init(searchUsersUseCase: SearchUsersUseCaseProtocol) {
        self.searchUsersUseCase = searchUsersUseCase
    }

    deinit {
        activeTask?.cancel()
    }

    var hasPendingSearchOptions: Bool {
        !activeQuery.isEmpty && currentOptions != activeOptions
    }

    func search() {
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        startSearch(query: currentQuery, options: currentOptions)
    }

    func refresh() async {
        guard !activeQuery.isEmpty else { return }

        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false

        let queryToRefresh = activeQuery
        let optionsToRefresh = activeOptions
        await loadPage(
            1,
            query: queryToRefresh,
            options: optionsToRefresh,
            replacingCurrentResults: true
        )
    }

    func loadNextPageIfNeeded(currentUser: GitHubUser) {
        guard currentUser.id == users.last?.id else { return }
        guard canLoadMore, !isLoadingNextPage, !activeQuery.isEmpty else { return }

        isLoadingNextPage = true
        let queryToLoad = activeQuery
        let optionsToLoad = activeOptions

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(
                self.currentPage + 1,
                query: queryToLoad,
                options: optionsToLoad,
                replacingCurrentResults: false
            )
            self.isLoadingNextPage = false
        }
    }

    func retry() {
        let retryQuery = activeQuery.isEmpty
            ? query.trimmingCharacters(in: .whitespacesAndNewlines)
            : activeQuery
        let retryOptions = activeQuery.isEmpty ? currentOptions : activeOptions

        query = retryQuery
        sort = retryOptions.sort
        order = retryOptions.order
        startSearch(query: retryQuery, options: retryOptions)
    }

    private var currentOptions: UserSearchOptions {
        UserSearchOptions(sort: sort, order: order)
    }

    private func startSearch(query: String, options: UserSearchOptions) {
        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false
        users = []
        totalCount = 0

        guard !query.isEmpty else {
            activeQuery = ""
            activeOptions = .default
            state = .idle
            return
        }

        activeQuery = query
        activeOptions = options
        state = .loading

        activeTask = Task { [weak self] in
            await self?.loadPage(
                1,
                query: query,
                options: options,
                replacingCurrentResults: true
            )
        }
    }

    private func loadPage(
        _ page: Int,
        query: String,
        options: UserSearchOptions,
        replacingCurrentResults: Bool
    ) async {
        do {
            let result = try await searchUsersUseCase.execute(
                query: query,
                options: options,
                page: page,
                perPage: pageSize
            )

            guard !Task.isCancelled else { return }
            guard query == activeQuery, options == activeOptions else { return }

            currentPage = page
            canLoadMore = result.hasNextPage
            totalCount = result.totalCount
            users = replacingCurrentResults ? result.users : users + result.users
            state = users.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            guard query == activeQuery, options == activeOptions else { return }
            state = .failed(error.localizedDescription)
        }
    }
}

enum UserProfileViewState: Equatable {
    case loading
    case loaded(GitHubUserProfile)
    case failed(String)
}

@MainActor
final class UserProfileViewModel: ObservableObject {
    let login: String

    @Published private(set) var state: UserProfileViewState = .loading

    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    private var activeTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        login: String,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    ) {
        self.login = login
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
    }

    deinit {
        activeTask?.cancel()
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        startLoading()
    }

    func retry() {
        startLoading()
    }

    func refresh() async {
        activeTask?.cancel()
        await loadProfile()
    }

    private func startLoading() {
        activeTask?.cancel()
        state = .loading

        activeTask = Task { [weak self] in
            await self?.loadProfile()
        }
    }

    private func loadProfile() async {
        do {
            let profile = try await fetchUserProfileUseCase.execute(login: login)
            guard !Task.isCancelled else { return }
            state = .loaded(profile)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}

enum UserRepositoriesViewState: Equatable {
    case loading
    case loaded
    case empty
    case failed(String)
}

@MainActor
final class UserRepositoriesViewModel: ObservableObject {
    let login: String

    @Published var sort: UserRepositorySort = .updated
    @Published var order: UserRepositoryOrder = .descending
    @Published private(set) var repositories: [GitHubRepository] = []
    @Published private(set) var state: UserRepositoriesViewState = .loading
    @Published private(set) var isLoadingNextPage = false

    private let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    private let pageSize = 20
    private var currentPage = 0
    private var canLoadMore = false
    private var activeOptions: UserRepositoryOptions = .default
    private var activeTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        login: String,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    ) {
        self.login = login
        self.fetchUserRepositoriesUseCase = fetchUserRepositoriesUseCase
    }

    deinit {
        activeTask?.cancel()
    }

    var hasPendingOptions: Bool {
        currentOptions != activeOptions
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        startLoading(options: currentOptions)
    }

    func applyOptions() {
        startLoading(options: currentOptions)
    }

    func retry() {
        sort = activeOptions.sort
        order = activeOptions.order
        startLoading(options: activeOptions)
    }

    func refresh() async {
        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false

        await loadPage(
            1,
            options: activeOptions,
            replacingCurrentResults: true
        )
    }

    func loadNextPageIfNeeded(currentRepository: GitHubRepository) {
        guard currentRepository.id == repositories.last?.id else { return }
        guard canLoadMore, !isLoadingNextPage else { return }

        isLoadingNextPage = true
        let optionsToLoad = activeOptions

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(
                self.currentPage + 1,
                options: optionsToLoad,
                replacingCurrentResults: false
            )
            self.isLoadingNextPage = false
        }
    }

    private var currentOptions: UserRepositoryOptions {
        UserRepositoryOptions(sort: sort, order: order)
    }

    private func startLoading(options: UserRepositoryOptions) {
        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false
        repositories = []
        activeOptions = options
        state = .loading

        activeTask = Task { [weak self] in
            await self?.loadPage(
                1,
                options: options,
                replacingCurrentResults: true
            )
        }
    }

    private func loadPage(
        _ page: Int,
        options: UserRepositoryOptions,
        replacingCurrentResults: Bool
    ) async {
        do {
            let result = try await fetchUserRepositoriesUseCase.execute(
                login: login,
                options: options,
                page: page,
                perPage: pageSize
            )

            guard !Task.isCancelled else { return }
            guard options == activeOptions else { return }

            currentPage = page
            canLoadMore = result.hasNextPage

            if replacingCurrentResults {
                repositories = result.repositories
            } else {
                let existingIDs = Set(repositories.map(\.id))
                repositories += result.repositories.filter { !existingIDs.contains($0.id) }
            }

            state = repositories.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            guard options == activeOptions else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
