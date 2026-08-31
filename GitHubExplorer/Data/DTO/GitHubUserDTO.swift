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

struct GitHubUserProfileDTO: Decodable {
    let id: Int
    let login: String
    let name: String?
    let avatarURL: URL?
    let htmlURL: URL?
    let bio: String?
    let company: String?
    let location: String?
    let blog: String?
    let followers: Int
    let following: Int
    let publicRepositories: Int

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case name
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case bio
        case company
        case location
        case blog
        case followers
        case following
        case publicRepositories = "public_repos"
    }

    func toDomain() -> GitHubUserProfile {
        GitHubUserProfile(
            id: id,
            login: login,
            name: name,
            avatarURL: avatarURL,
            profileURL: htmlURL,
            bio: bio,
            company: company,
            location: location,
            websiteURL: normalizedWebsiteURL,
            followers: followers,
            following: following,
            publicRepositories: publicRepositories
        )
    }

    private var normalizedWebsiteURL: URL? {
        guard let rawValue = blog?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }

        if let url = URL(string: rawValue), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(rawValue)")
    }
}
