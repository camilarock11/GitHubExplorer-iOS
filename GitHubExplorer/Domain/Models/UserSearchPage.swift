struct UserSearchPage: Equatable {
    let users: [GitHubUser]
    let totalCount: Int
    let page: Int
    let perPage: Int

    private var searchableCount: Int {
        min(totalCount, 1_000)
    }

    var hasNextPage: Bool {
        page * perPage < searchableCount
    }
}
