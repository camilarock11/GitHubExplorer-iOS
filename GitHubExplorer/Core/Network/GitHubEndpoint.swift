import Foundation

enum GitHubEndpoint: Endpoint {
    case searchUsers(query: String, page: Int, perPage: Int)

    var path: String {
        switch self {
        case .searchUsers:
            return "/search/users"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .searchUsers(query, page, perPage):
            return [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
        }
    }
}
