# Architecture

## Goal

Keep the app easy to evolve while making responsibilities explicit enough to support testing, feature growth and future modularization.

## Presentation: MVVM

Each feature owns its SwiftUI views and ViewModels. Views render state and forward user intent. ViewModels orchestrate presentation state and call use cases.

```text
Features/
  Search/
    SearchView.swift
    SearchViewModel.swift
    SearchViewState.swift
```

## Domain

Domain types know nothing about SwiftUI, URLSession or GitHub JSON shapes.

- `Models`: business-facing entities
- `UseCases`: app operations
- `Repositories`: contracts required by use cases

## Data

The data layer implements domain repository contracts and maps external DTOs into domain models.

```text
GitHub JSON → DTO → Repository → Domain Model
```

This prevents API response details such as `avatar_url` from leaking throughout the app.

## Core

Cross-feature infrastructure lives under `Core`.

The networking layer is deliberately built on URLSession rather than a third-party dependency so the project demonstrates request construction, HTTP validation, decoding and error mapping directly.

## Dependency direction

```text
Features → Domain ← Data
                ↑
              Core
```

The domain layer must not import UI or concrete data implementations.

## Future modularization

The initial repository is a single Xcode project so the architecture remains easy to navigate. Once feature boundaries are stable, selected layers can be extracted into Swift Packages without changing the public contracts.
