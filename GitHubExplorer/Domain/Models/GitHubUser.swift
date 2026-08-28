import Foundation

struct GitHubUser: Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarURL: URL?
    let profileURL: URL?
}
