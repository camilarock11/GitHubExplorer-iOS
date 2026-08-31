import Foundation

enum GitHubEndpoint: Endpoint {
    case searchUsers(
        query: String,
        sort: String?,
        order: String?,
        page: Int,
        perPage: Int
    )

    var path: String {
        switch self {
        case .searchUsers:
            return "/search/users"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .searchUsers(query, sort, order, page, perPage):
            var items = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]

            if let sort {
                items.append(URLQueryItem(name: "sort", value: sort))

                if let order {
                    items.append(URLQueryItem(name: "order", value: order))
                }
            }

            return items
        }
    }
}
