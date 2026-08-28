import SwiftUI

struct RootView: View {
    private let searchViewModel: SearchViewModel

    init(searchViewModel: SearchViewModel) {
        self.searchViewModel = searchViewModel
    }

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(viewModel: searchViewModel)
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
