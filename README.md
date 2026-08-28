# GitHubExplorer-iOS

A production-minded GitHub explorer built with SwiftUI and MVVM. The project is intentionally structured as a portfolio-quality iOS codebase rather than a tutorial app.

## Current vertical slice

- Search GitHub users through the public GitHub REST API
- Paginated loading
- Loading, empty and error states
- Pull-to-refresh
- MVVM presentation layer
- Use Case + Repository boundaries
- Generic async/await networking client
- DTO-to-domain mapping
- Dependency injection
- Unit tests for the Search ViewModel
- CI workflow for build and tests

## Architecture

```text
SwiftUI View
    ↓
ViewModel
    ↓
Use Case
    ↓
Repository Protocol
    ↓
Repository Implementation
    ↓
API Client
    ↓
GitHub REST API
```

The app uses **MVVM** as the presentation architecture while keeping business rules and data access behind explicit boundaries.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the decisions and dependency rules.

## Tech stack

- Swift
- SwiftUI
- MVVM
- Swift Concurrency (`async/await`)
- URLSession
- Codable
- XCTest
- GitHub Actions

## Requirements

- Xcode 16.2+
- iOS 17+
- Swift 5 mode

## Run

1. Open `GitHubExplorer.xcodeproj`.
2. Select the `GitHubExplorer` scheme.
3. Run on an iOS 17+ simulator.

No third-party dependencies are required.

> The unauthenticated GitHub API has rate limits. Token-based authentication is intentionally reserved for a later milestone.

## Roadmap

| Ticket | Scope | Status |
| --- | --- | --- |
| GE-001 | Project architecture + vertical slice | ✅ |
| GE-002 | Harden networking + request tests | ⏳ |
| GE-003 | Advanced user search + debounce + filters | ⏳ |
| GE-004 | Full profile screen | ⏳ |
| GE-005 | Repository list + pagination | ⏳ |
| GE-006 | Repository details + languages | ⏳ |
| GE-007 | Favorites + local persistence | ⏳ |
| GE-008 | Issues + pull requests | ⏳ |
| GE-009 | Commits + contributors + branches | ⏳ |
| GE-010 | Cache/offline support | ⏳ |
| GE-011 | Design system + accessibility pass | ⏳ |
| GE-012 | Performance + observability | ⏳ |
| GE-013 | Snapshot/UI tests | ⏳ |
| GE-014 | Release automation | ⏳ |
| GE-015 | v1.0 portfolio release | ⏳ |

## Branch and PR convention

```text
feature/GE-004-profile
fix/GE-021-rate-limit-state
chore/GE-001-project-setup
```

PR title example:

```text
FEAT: [GE-004] Implement user profile
```

Commit example:

```text
feat: implement user profile header
```

## License

MIT
