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

struct GitHubRepositoryDTO: Decodable {
    let id: Int
    let name: String
    let description: String?
    let htmlURL: URL?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case htmlURL = "html_url"
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case updatedAt = "updated_at"
    }

    func toDomain() -> GitHubRepository {
        GitHubRepository(
            id: id,
            name: name,
            description: description,
            htmlURL: htmlURL,
            language: language,
            stargazersCount: stargazersCount,
            forksCount: forksCount,
            updatedAt: updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

struct GitHubRepositoryDetailsDTO: Decodable {
    struct LicenseDTO: Decodable {
        let name: String?
    }

    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlURL: URL?
    let isPrivate: Bool
    let defaultBranch: String
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let subscribersCount: Int?
    let legacyWatchersCount: Int?
    let openIssuesCount: Int
    let license: LicenseDTO?
    let topics: [String]?
    let createdAt: String?
    let updatedAt: String?
    let pushedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case htmlURL = "html_url"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case subscribersCount = "subscribers_count"
        case legacyWatchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case license
        case topics
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }

    func toDomain() -> GitHubRepositoryDetails {
        let formatter = ISO8601DateFormatter()

        return GitHubRepositoryDetails(
            id: id,
            name: name,
            fullName: fullName,
            description: description,
            htmlURL: htmlURL,
            isPrivate: isPrivate,
            defaultBranch: defaultBranch,
            language: language,
            stargazersCount: stargazersCount,
            forksCount: forksCount,
            watchersCount: subscribersCount ?? legacyWatchersCount ?? 0,
            openIssuesCount: openIssuesCount,
            licenseName: license?.name,
            topics: topics ?? [],
            createdAt: createdAt.flatMap { formatter.date(from: $0) },
            updatedAt: updatedAt.flatMap { formatter.date(from: $0) },
            pushedAt: pushedAt.flatMap { formatter.date(from: $0) }
        )
    }
}
