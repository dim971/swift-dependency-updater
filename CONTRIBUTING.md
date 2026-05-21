# Contributing to SwiftDependencyUpdater

Thanks for taking the time to contribute. This document covers everything you need to make your first PR land smoothly.

## Prerequisites

- macOS 13 or later
- Swift 6.2 (`swift --version` should match)
- Xcode 16+ recommended

## Getting started

```bash
git clone https://github.com/dim971/swift-dependency-updater.git
cd swift-dependency-updater
swift build
swift test
```

If `swift build` succeeds and `swift test` is green, you're ready.

## Project layout

| Path | What it is |
| --- | --- |
| `Sources/DependencyUpdaterCore/` | Library — all parsing/matching/rewriting logic. **Most changes go here.** |
| `Sources/DependencyUpdaterExecutable/` | Thin CLI binary invoked by the plugin. |
| `Sources/DependencyUpdater/Plugins/` | SPM command plugin (`update-dependencies` verb). |
| `Tests/DependencyUpdaterTests/` | XCTest target covering Core. |
| `.github/workflows/` | CI: tests + automatic release tagging. |

A deeper architectural note for AI assistants is in [`CLAUDE.md`](CLAUDE.md).

## Branching model

```
feature/* ──► develop ──► main ──► tag vX.Y.Z (automatic)
```

- **`main`** is always shippable. Never push directly.
- **`develop`** is the integration branch. Open your feature PR against `develop`.
- A maintainer opens a `develop → main` PR when it's time to release; merging it auto-tags.

## Opening a PR

1. Fork the repo and create a branch off `develop`: `git checkout -b my-feature origin/develop`.
2. Make focused commits. Short imperative subjects (e.g. `Fix multi-line package declaration parsing`).
3. Add or update tests under `Tests/DependencyUpdaterTests/` for any change in Core.
4. Run `make test` locally — it mirrors CI exactly.
5. Open a PR **against `develop`**, not `main`. Describe *what* and *why*; the *how* is in the diff.
6. CI runs automatically. A coverage summary is posted as a PR comment.

## Release process (maintainers)

Releases are automated. To cut one:

1. Open a PR from `develop` to `main`.
2. Apply **one** label to the PR:
   - `release:major` — breaking changes
   - `release:minor` — new features, backward-compatible
   - `release:patch` — bug fixes only (this is the default if no label is set)
3. Merge the PR. The `release.yml` workflow will:
   - Compute the next version from the latest `v*` tag.
   - Create the tag on `main`.
   - Publish a GitHub Release with auto-generated notes.

The very first release is forced to `v0.1.0` regardless of label.

## Reporting issues

Open a GitHub issue with:
- What you ran (exact command).
- What you expected.
- What happened instead (paste output, not screenshots when possible).
- Minimal `Package.swift` + `dependencies.yaml` that reproduces the problem, if applicable.

## Code of conduct

Be kind. Assume good faith. Disagree on the technical merits, not the person. Maintainers reserve the right to lock or close threads that don't follow this.
