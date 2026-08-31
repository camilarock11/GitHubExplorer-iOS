import SwiftUI

struct RootView: View {
    private let searchViewModel: SearchViewModel
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol

    init(
        searchViewModel: SearchViewModel,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    ) {
        self.searchViewModel = searchViewModel
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
    }

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(
                    viewModel: searchViewModel,
                    fetchUserProfileUseCase: fetchUserProfileUseCase
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
