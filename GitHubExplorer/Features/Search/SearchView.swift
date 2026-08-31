import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol

    init(
        viewModel: SearchViewModel,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                searchOptionsMenu
            }
        }
    }

    private var searchOptionsMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sort) {
                ForEach(UserSearchSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            if viewModel.sort != .bestMatch {
                Picker("Order", selection: $viewModel.order) {
                    ForEach(UserSearchOrder.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            if viewModel.hasPendingSearchOptions {
                Divider()

                Button {
                    viewModel.search()
                } label: {
                    Label("Apply sorting", systemImage: "checkmark")
                }
            }
        } label: {
            Label("Search options", systemImage: "arrow.up.arrow.down.circle")
        }
    }

    private var userList: some View {
        List {
            Section {
                ForEach(viewModel.users) { user in
                    NavigationLink {
                        UserProfileView(
                            login: user.login,
                            fetchUserProfileUseCase: fetchUserProfileUseCase
                        )
                    } label: {
                        UserRowView(user: user)
                    }
                    .onAppear {
                        viewModel.loadNextPageIfNeeded(currentUser: user)
                    }
                }
            } header: {
                Text("\(viewModel.totalCount) results")
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
            await viewModel.refresh()
        }
    }
}

struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel

    @MainActor
    init(
        login: String,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: UserProfileViewModel(
                login: login,
                fetchUserProfileUseCase: fetchUserProfileUseCase
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(profile):
                profileContent(profile)
            case let .failed(message):
                ContentUnavailableView {
                    Label("Profile unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: viewModel.retry)
                }
            }
        }
        .navigationTitle(viewModel.login)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private func profileContent(_ profile: GitHubUserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(profile)
                metrics(profile)
                metadata(profile)
                links(profile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func header(_ profile: GitHubUserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                AsyncImage(url: profile.avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    if let name = profile.name, !name.isEmpty {
                        Text(name)
                            .font(.title2.bold())
                    }

                    Text("@\(profile.login)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
            }
        }
    }

    private func metrics(_ profile: GitHubUserProfile) -> some View {
        HStack(spacing: 12) {
            ProfileMetricView(value: profile.followers, title: "Followers")
            ProfileMetricView(value: profile.following, title: "Following")
            ProfileMetricView(value: profile.publicRepositories, title: "Repositories")
        }
    }

    @ViewBuilder
    private func metadata(_ profile: GitHubUserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let company = profile.company, !company.isEmpty {
                Label(company, systemImage: "building.2")
            }

            if let location = profile.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func links(_ profile: GitHubUserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let websiteURL = profile.websiteURL {
                Link(destination: websiteURL) {
                    Label("Website", systemImage: "link")
                }
            }

            if let profileURL = profile.profileURL {
                Link(destination: profileURL) {
                    Label("Open on GitHub", systemImage: "arrow.up.right.square")
                }
            }
        }
        .font(.headline)
    }
}

private struct ProfileMetricView: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value.formatted())
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
