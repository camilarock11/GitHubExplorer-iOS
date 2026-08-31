import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    private let fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol
    private let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    private let fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol

    init(
        viewModel: SearchViewModel,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol,
        fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.fetchUserProfileUseCase = fetchUserProfileUseCase
        self.fetchUserRepositoriesUseCase = fetchUserRepositoriesUseCase
        self.fetchRepositoryDetailsUseCase = fetchRepositoryDetailsUseCase
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
                            fetchUserProfileUseCase: fetchUserProfileUseCase,
                            fetchUserRepositoriesUseCase: fetchUserRepositoriesUseCase,
                            fetchRepositoryDetailsUseCase: fetchRepositoryDetailsUseCase
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
    private let fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol
    private let fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol

    @MainActor
    init(
        login: String,
        fetchUserProfileUseCase: FetchUserProfileUseCaseProtocol,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol,
        fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: UserProfileViewModel(
                login: login,
                fetchUserProfileUseCase: fetchUserProfileUseCase
            )
        )
        self.fetchUserRepositoriesUseCase = fetchUserRepositoriesUseCase
        self.fetchRepositoryDetailsUseCase = fetchRepositoryDetailsUseCase
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

            NavigationLink {
                UserRepositoriesView(
                    login: profile.login,
                    fetchUserRepositoriesUseCase: fetchUserRepositoriesUseCase,
                    fetchRepositoryDetailsUseCase: fetchRepositoryDetailsUseCase
                )
            } label: {
                ProfileMetricView(
                    value: profile.publicRepositories,
                    title: "Repositories"
                )
            }
            .buttonStyle(.plain)
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

struct UserRepositoriesView: View {
    @StateObject private var viewModel: UserRepositoriesViewModel
    private let fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol

    @MainActor
    init(
        login: String,
        fetchUserRepositoriesUseCase: FetchUserRepositoriesUseCaseProtocol,
        fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: UserRepositoriesViewModel(
                login: login,
                fetchUserRepositoriesUseCase: fetchUserRepositoriesUseCase
            )
        )
        self.fetchRepositoryDetailsUseCase = fetchRepositoryDetailsUseCase
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading repositories…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView(
                    "No repositories",
                    systemImage: "folder",
                    description: Text("This user has no public repositories to show.")
                )
            case let .failed(message):
                ContentUnavailableView {
                    Label("Repositories unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: viewModel.retry)
                }
            case .loaded:
                repositoryList
            }
        }
        .navigationTitle("Repositories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                repositoryOptionsMenu
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var repositoryList: some View {
        List(viewModel.repositories) { repository in
            NavigationLink {
                RepositoryDetailsView(
                    owner: viewModel.login,
                    name: repository.name,
                    fetchRepositoryDetailsUseCase: fetchRepositoryDetailsUseCase
                )
            } label: {
                RepositoryRowView(repository: repository)
            }
            .onAppear {
                viewModel.loadNextPageIfNeeded(currentRepository: repository)
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

    private var repositoryOptionsMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sort) {
                ForEach(UserRepositorySort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Picker("Order", selection: $viewModel.order) {
                ForEach(UserRepositoryOrder.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            if viewModel.hasPendingOptions {
                Divider()

                Button {
                    viewModel.applyOptions()
                } label: {
                    Label("Apply sorting", systemImage: "checkmark")
                }
            }
        } label: {
            Label("Repository options", systemImage: "arrow.up.arrow.down.circle")
        }
    }
}

struct RepositoryDetailsView: View {
    @StateObject private var viewModel: RepositoryDetailsViewModel

    @MainActor
    init(
        owner: String,
        name: String,
        fetchRepositoryDetailsUseCase: FetchRepositoryDetailsUseCaseProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: RepositoryDetailsViewModel(
                owner: owner,
                name: name,
                fetchRepositoryDetailsUseCase: fetchRepositoryDetailsUseCase
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading repository…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(details):
                detailsContent(details)
            case let .failed(message):
                ContentUnavailableView {
                    Label("Repository unavailable", systemImage: "folder.badge.questionmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: viewModel.retry)
                }
            }
        }
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private func detailsContent(_ details: GitHubRepositoryDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                repositoryHeader(details)
                repositoryMetrics(details)
                repositoryMetadata(details)

                if !details.topics.isEmpty {
                    repositoryTopics(details.topics)
                }

                repositoryDates(details)

                if let htmlURL = details.htmlURL {
                    Link(destination: htmlURL) {
                        Label("Open on GitHub", systemImage: "arrow.up.right.square")
                            .font(.headline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func repositoryHeader(_ details: GitHubRepositoryDetails) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(details.fullName)
                .font(.title2.bold())
                .textSelection(.enabled)

            Label(
                details.isPrivate ? "Private" : "Public",
                systemImage: details.isPrivate ? "lock.fill" : "globe"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let description = details.description, !description.isEmpty {
                Text(description)
                    .font(.body)
            }
        }
    }

    private func repositoryMetrics(_ details: GitHubRepositoryDetails) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            DetailMetricView(value: details.stargazersCount, title: "Stars", systemImage: "star")
            DetailMetricView(value: details.forksCount, title: "Forks", systemImage: "tuningfork")
            DetailMetricView(value: details.watchersCount, title: "Watchers", systemImage: "eye")
            DetailMetricView(value: details.openIssuesCount, title: "Open issues", systemImage: "exclamationmark.circle")
        }
    }

    private func repositoryMetadata(_ details: GitHubRepositoryDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(details.defaultBranch, systemImage: "arrow.triangle.branch")

            if let language = details.language, !language.isEmpty {
                Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
            }

            if let licenseName = details.licenseName, !licenseName.isEmpty {
                Label(licenseName, systemImage: "doc.text")
            }
        }
        .font(.subheadline)
    }

    private func repositoryTopics(_ topics: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Topics")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    private func repositoryDates(_ details: GitHubRepositoryDetails) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let createdAt = details.createdAt {
                Label(
                    "Created \(createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar.badge.plus"
                )
            }

            if let updatedAt = details.updatedAt {
                Label(
                    "Updated \(updatedAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "clock.arrow.circlepath"
                )
            }

            if let pushedAt = details.pushedAt {
                Label(
                    "Last push \(pushedAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "arrow.up.circle"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct RepositoryRowView: View {
    let repository: GitHubRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(repository.name)
                .font(.headline)

            if let description = repository.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 14) {
                if let language = repository.language, !language.isEmpty {
                    Label(language, systemImage: "circle.fill")
                }

                Label(repository.stargazersCount.formatted(), systemImage: "star")
                Label(repository.forksCount.formatted(), systemImage: "tuningfork")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let updatedAt = repository.updatedAt {
                Label(
                    "Updated \(updatedAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DetailMetricView: View {
    let value: Int
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
