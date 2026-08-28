import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ContentUnavailableView(
                    "Explore GitHub",
                    systemImage: "person.2",
                    description: Text("Search for a GitHub username to start exploring.")
                )
            case .loading:
                ProgressView("Searching GitHub…")
            case .empty:
                ContentUnavailableView.search(text: viewModel.query)
            case let .failed(message):
                ContentUnavailableView {
                    Label("Something went wrong", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: viewModel.retry)
                }
            case .loaded:
                userList
            }
        }
        .navigationTitle("GitHub Explorer")
        .searchable(text: $viewModel.query, prompt: "Search users")
        .onSubmit(of: .search, viewModel.search)
    }

    private var userList: some View {
        List(viewModel.users) { user in
            Link(destination: user.profileURL ?? URL(string: "https://github.com")!) {
                UserRowView(user: user)
            }
            .buttonStyle(.plain)
            .onAppear {
                viewModel.loadNextPageIfNeeded(currentUser: user)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoadingNextPage {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom)
            }
        }
        .refreshable {
            viewModel.search()
        }
    }
}
