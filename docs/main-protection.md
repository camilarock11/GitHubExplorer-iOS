# Main branch protection

This repository uses pull requests and automated quality checks to keep `main` stable.

## Pull request conventions

- Title: `TYPE: [O1] Description`
- Branch: `type/o1-short-description`
- The PR type and objective must match the branch.
- `Objective`, `Changes`, and `How to test` must be filled in.
- All checklist items must be completed before merge.

## Recommended `main` ruleset

- Require a pull request before merging.
- Require status checks to pass before merging.
- Require the branch to be up to date before merging.
- Required check: `Validate PR conventions`.
- Block force pushes.
- Block branch deletion.
- Keep required approvals at `0` while the repository has a single maintainer.
