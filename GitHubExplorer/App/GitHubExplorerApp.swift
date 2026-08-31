import SwiftUI

@main
struct GitHubExplorerApp: App {
    private let container = DependencyContainer.live

    var body: some Scene {
        WindowGroup {
            RootView(
                searchViewModel: container.makeSearchViewModel(),
                fetchUserProfileUseCase: container.fetchUserProfileUseCase
            )
        }
    }
}
