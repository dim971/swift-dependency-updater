# SwiftDependencyUpdater — Claude guide

This file gives Claude Code the context it needs to help contributors work effectively on this repository. Keep it tight; update it when conventions change.

## What this project is

A Swift Package Manager **plugin** that synchronizes dependency versions in `Package.swift` files (and `.pbxproj` files) from a central `Dependencies/dependencies.yaml`. End-user usage is documented in [README.md](README.md).

## Architecture

Three SPM targets in `Sources/`:

| Target | Path | Role |
| --- | --- | --- |
| `DependencyUpdaterCore` | `Sources/DependencyUpdaterCore/` | Library — parsing, matching, file rewriting. All real logic lives here. |
| `DependencyUpdaterExecutable` | `Sources/DependencyUpdaterExecutable/` | Thin CLI wrapper around Core. Invoked by the plugin. |
| `DependencyUpdater` | `Sources/DependencyUpdater/Plugins/` | The SPM `.command` plugin (`update-dependencies` verb). |

Tests live in `Tests/DependencyUpdaterTests/` and exercise the Core target.

External dependency: `Yams` (YAML parsing), pinned exactly.

## Build, test, run

```bash
swift build                                # build all targets
swift test                                 # run tests
swift test --enable-code-coverage          # run tests + capture coverage (CI)
make test                                  # tests + coverage report (uses llvm-cov)
```

To exercise the plugin against a sample project:

```bash
swift package plugin update-dependencies --allow-writing-to-package-directory
```

The `--allow-writing-to-package-directory` flag is required because the plugin mutates `Package.swift` files.

## Branching & release flow

- **`main`** is always shippable. Direct pushes are forbidden — every change lands via PR.
- **`develop`** is the integration branch. Feature branches PR into `develop`.
- Tags are created **automatically** when a PR from `develop` is merged into `main`, via [`.github/workflows/release.yml`](.github/workflows/release.yml).

### Versioning (semver, tags prefixed `v`)

The release workflow reads PR labels on the `develop → main` PR:

| Label | Bump |
| --- | --- |
| `release:major` | x → (x+1).0.0 |
| `release:minor` | x.y → x.(y+1).0 |
| `release:patch` *(default)* | x.y.z → x.y.(z+1) |

If no tag exists yet, the first release is forced to `v0.1.0` regardless of label.

## Conventions

- **Swift tools version**: 6.2 (declared in `Package.swift`).
- **Platforms**: macOS 13+.
- **Commits**: short imperative subject (e.g. `Fix yaml parser on multi-line values`). No required format; conventional commits are welcome but not enforced.
- **Tests required** for any logic change in `DependencyUpdaterCore`. The plugin and executable targets are thin and rarely need direct tests.
- **No new dependencies** without justification — this project intentionally has a tiny dependency surface.

## Gotchas

- The plugin matches packages by the **last path component** of the URL (stripping `.git`). Changing this rule is a breaking change.
- Only `.package(... exact: "...")` declarations are rewritten. `from:` / range requirements are intentionally left alone.
- `Package.resolved` is **gitignored**. Don't try to commit it.
- `.claude/settings.local.json` is per-user — never commit it. The shared `.claude/settings.json` is the only Claude config that ships.

## When in doubt

- Open questions about scope or breaking changes → ask in the PR description rather than guessing.
- Local CI parity: run `make test` before pushing; it mirrors what GitHub Actions does.
