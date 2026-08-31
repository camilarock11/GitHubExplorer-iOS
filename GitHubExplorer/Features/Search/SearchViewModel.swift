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
