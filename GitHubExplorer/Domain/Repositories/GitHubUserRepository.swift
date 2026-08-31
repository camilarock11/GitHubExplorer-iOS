enum UserSearchSort: String, CaseIterable, Identifiable {
    case bestMatch
    case followers
    case repositories
    case joined

    var id: String { rawValue }

    var apiValue: String? {
        self == .bestMatch ? nil : rawValue
    }

    var title: String {
        switch self {
        case .bestMatch:
            return "Best match"
        case .followers:
            return "Followers"
        case .repositories:
            return "Repositories"
        case .joined:
            return "Joined"
        }
    }
}

enum UserSearchOrder: String, CaseIterable, Identifiable {
    case descending = "desc"
    case ascending = "asc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .descending:
            return "Descending"
        case .ascending:
            return "Ascending"
        }
    }
}

struct UserSearchOptions: Equatable {
    let sort: UserSearchSort
    let order: UserSearchOrder

    static let `default` = UserSearchOptions(
        sort: .bestMatch,
        order: .descending
    )
}

protocol GitHubUserRepository {
    func searchUsers(
        query: String,
        options: UserSearchOptions,
        page: Int,
        perPage: Int
    ) async throws -> UserSearchPage

    func fetchUserProfile(login: String) async throws -> GitHubUserProfile
}
