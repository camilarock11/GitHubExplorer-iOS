import SwiftUI

struct RootView: View {
    private let searchViewModel: SearchViewModel
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    private let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    private let fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol

    init(
        searchViewModel: SearchViewModel,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol,
        fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol
    ) {
        self.searchViewModel = searchViewModel
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchUserRepositoriesUseCase = fetchUserRepositoriesUseCase
        self.fetchRepositoryDetailsUseCase = fetchRepositoryDetailsUseCase
    }

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(
                    viewModel: searchViewModel,
                    fetchUserProfileUseCase: fetchUserProfileUseCase,
                    fetchUserRepositoriesUseCase: fetchUserRepositoriesUseCase,
                    fetchRepositoryDetailsUseCase: fetchRepositoryDetailsUseCase
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
