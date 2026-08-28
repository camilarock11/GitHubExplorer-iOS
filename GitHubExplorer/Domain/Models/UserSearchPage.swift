struct UserSearchPage: Equatable {
    let users: [GitHubUser]
    let totalCount: Int
    let page: Int
    let perPage: Int

    var hasNextPage: Bool {
        page * perPage < totalCount
    }
}
