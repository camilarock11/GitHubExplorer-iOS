import Foundation

struct GitHubUser: Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarURL: URL?
    let profileURL: URL?
}

struct GitHubUserProfile: Equatable {
    let id: Int
    let login: String
    let name: String?
    let avatarURL: URL?
    let profileURL: URL?
    let bio: String?
    let company: String?
    let location: String?
    let websiteURL: URL?
    let followers: Int
    let following: Int
    let publicRepositories: Int
}

struct GitHubRepository: Identifiable, Equatable {
    let id: Int
    let name: String
    let description: String?
    let htmlURL: URL?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let updatedAt: Date?
}

struct UserRepositoriesPage: Equatable {
    let repositories: [GitHubRepository]
    let page: Int
    let perPage: Int

    var hasNextPage: Bool {
        repositories.count == perPage
    }
}
