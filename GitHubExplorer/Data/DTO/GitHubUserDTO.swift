import Foundation

struct GitHubUserDTO: Decodable {
    let id: Int
    let login: String
    let avatarURL: URL?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }

    func toDomain() -> GitHubUser {
        GitHubUser(
            id: id,
            login: login,
            avatarURL: avatarURL,
            profileURL: htmlURL
        )
    }
}

struct SearchUsersResponseDTO: Decodable {
    let totalCount: Int
    let items: [GitHubUserDTO]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}
