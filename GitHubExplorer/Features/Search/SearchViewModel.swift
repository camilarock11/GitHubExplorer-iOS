import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var users: [GitHubUser] = []
    @Published private(set) var state: SearchViewState = .idle
    @Published private(set) var isLoadingNextPage = false

    private let searchUsersUseCase: SearchUsersUseCaseProtocol
    private let pageSize = 20
    private var currentPage = 0
    private var canLoadMore = false
    private var activeQuery = ""
    private var activeTask: Task<Void, Never>?

    init(searchUsersUseCase: SearchUsersUseCaseProtocol) {
        self.searchUsersUseCase = searchUsersUseCase
    }

    deinit {
        activeTask?.cancel()
    }

    func search() {
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        startSearch(query: currentQuery)
    }

    func refresh() async {
        guard !activeQuery.isEmpty else { return }

        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false

        let queryToRefresh = activeQuery
        await loadPage(
            1,
            query: queryToRefresh,
            replacingCurrentResults: true
        )
    }

    func loadNextPageIfNeeded(currentUser: GitHubUser) {
        guard currentUser.id == users.last?.id else { return }
        guard canLoadMore, !isLoadingNextPage, !activeQuery.isEmpty else { return }

        isLoadingNextPage = true
        let queryToLoad = activeQuery

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(
                self.currentPage + 1,
                query: queryToLoad,
                replacingCurrentResults: false
            )
            self.isLoadingNextPage = false
        }
    }

    func retry() {
        let retryQuery = activeQuery.isEmpty
            ? query.trimmingCharacters(in: .whitespacesAndNewlines)
            : activeQuery

        query = retryQuery
        startSearch(query: retryQuery)
    }

    private func startSearch(query: String) {
        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        isLoadingNextPage = false
        users = []

        guard !query.isEmpty else {
            activeQuery = ""
            state = .idle
            return
        }

        activeQuery = query
        state = .loading

        activeTask = Task { [weak self] in
            await self?.loadPage(
                1,
                query: query,
                replacingCurrentResults: true
            )
        }
    }

    private func loadPage(
        _ page: Int,
        query: String,
        replacingCurrentResults: Bool
    ) async {
        do {
            let result = try await searchUsersUseCase.execute(
                query: query,
                page: page,
                perPage: pageSize
            )

            guard !Task.isCancelled else { return }
            guard query == activeQuery else { return }

            currentPage = page
            canLoadMore = result.hasNextPage
            users = replacingCurrentResults ? result.users : users + result.users
            state = users.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            guard query == activeQuery else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
