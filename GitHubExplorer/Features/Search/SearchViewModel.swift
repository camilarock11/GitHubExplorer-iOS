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
    private var activeTask: Task<Void, Never>?

    init(searchUsersUseCase: SearchUsersUseCaseProtocol) {
        self.searchUsersUseCase = searchUsersUseCase
    }

    deinit {
        activeTask?.cancel()
    }

    func search() {
        activeTask?.cancel()
        currentPage = 0
        canLoadMore = false
        users = []

        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else {
            state = .idle
            return
        }

        state = .loading
        activeTask = Task { [weak self] in
            await self?.loadPage(1, replacingCurrentResults: true)
        }
    }

    func loadNextPageIfNeeded(currentUser: GitHubUser) {
        guard currentUser.id == users.last?.id else { return }
        guard canLoadMore, !isLoadingNextPage else { return }

        isLoadingNextPage = true
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(self.currentPage + 1, replacingCurrentResults: false)
            self.isLoadingNextPage = false
        }
    }

    func retry() {
        search()
    }

    private func loadPage(_ page: Int, replacingCurrentResults: Bool) async {
        do {
            let result = try await searchUsersUseCase.execute(
                query: query,
                page: page,
                perPage: pageSize
            )

            guard !Task.isCancelled else { return }

            currentPage = page
            canLoadMore = result.hasNextPage
            users = replacingCurrentResults ? result.users : users + result.users
            state = users.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
