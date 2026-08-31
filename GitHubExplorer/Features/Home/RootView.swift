import SwiftUI

struct RootView: View {
    private let searchViewModel: SearchViewModel
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    private let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol

    init(
        searchViewModel: SearchViewModel,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    ) {
        self.searchViewModel = searchViewModel
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchUserRepositoriesUseCase = fetchUserRepositoriesUseCase
    }

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(
                    viewModel: searchViewModel,
                    fetchUserProfileUseCase: fetchUserProfileUseCase,
                    fetchUserRepositoriesUseCase: fetchUserRepositoriesUseCase
                )
            }
            .tabItem {
                Label("Explore", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ContentUnavailableView(
                    "Favorites",
                    systemImage: "star",
                    description: Text("Favorites arrive in GE-007.")
                )
                .navigationTitle("Favorites")
            }
            .tabItem {
                Label("Favorites", systemImage: "star")
            }
        }
    }
}
