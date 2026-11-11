# Rolling the standard out to a repository

What applying this template to proc and curb taught us, in the order the pull requests go. Each step is its own PR
(small repos may combine 1 + 2), stacked on the previous one, labelled with exactly one release label.

## 1. SDK 11, mise, shared CI, zizmor (label `ci`)

- `global.json`: `sdk.version` → `11.0.100`, `rollForward: latestFeature`, `allowPrerelease: false`. Do not add
  `test.runner` yet unless the tests already run on Microsoft.Testing.Platform (TUnit does; VSTest/xUnit v2 breaks).
- `mise.toml` from `template/mise.toml`. The first `dotnet` entry reads the SDK from `global.json`; **append every
  older runtime the tests target** (`"10"` for a `net10.0` test leg), because mise installs only what is listed.
  Keep only the tasks that work in this PR (`format`/`check` with curb come in step 5; `release` in step 3).
  Map tasks onto the repo's existing build targets; add `pack`/`ci` targets to the F# build only when it has none.
- CI: replace `actions/setup-dotnet` with `jdx/mise-action` (`cache: false` when the workflow publishes what it builds,
  `env: MISE_JOBS: "1"` — parallel dotnet installs into one `DOTNET_ROOT` race on Linux). Simple repos call
  `dotnet-ci.yml`; repos with bespoke CI keep their jobs and only swap the setup.
- Pin every action by SHA with a `# vX.Y.Z` comment naming a tag that points at it (zizmor's online audit checks the
  comment). Resolve with `gh api repos/<o>/<a>/commits/<tag> --jq .sha`; for `elastic/*` (SAML), use
  `git ls-remote --tags https://github.com/elastic/<repo>.git`.
- `persist-credentials: false` on every checkout that does not push. Secrets and step outputs reach `run:` through
  `env:`, never `${{ }}` inside the script. A setup-dotnet `source-url` used for a canary push becomes an explicit
  `-s https://nuget.pkg.github.com/nullean/index.json` on the push.
- Add the `zizmor` job (reusable `zizmor.yml`). Locally: `GH_TOKEN=$(gh auth token) zizmor --min-severity medium .`
  must report no findings; `mise exec shellcheck@latest -- actionlint .github/workflows/*.yml` must pass.
- SDK 11's analyzers add style rules (IDE0028 with a comparer → `[with(StringComparer.X), ...]`, IDE0410 labeled
  break). Under `EnforceCodeStyleInBuild` + warnings as errors they fail the build: fix them with
  `dotnet format style <sln> --diagnostics IDE0028 IDE0410 --severity warn`, then revert anything else it touched
  (it re-sorts usings) and fix its layout by hand. Check BOMs survived.
- Run `mise run ci` locally and record the test counts before and after; they must match.
- `AGENTS.md` (+ `CLAUDE.md` pointing at it) documents the `mise run` tasks.

## 2. CPM, package metadata, in-package skills (label `enhancement`)

- `Directory.Packages.props` with every version; strip `Version=` from `PackageReference` (including `build/scripts`).
- **F# projects under CPM lose the SDK's implicit FSharp.Core**: add `<PackageReference Include="FSharp.Core" />` to
  every `.fsproj` and a `PackageVersion` for it (a library's floor, e.g. 10.0.100). Check with
  `jq '.targets[][] | keys' obj/project.assets.json` — without it they resolve none, or an old one transitively.
- Metadata in `Directory.Build.props` (see `standards/Directory.Build.props`): `Authors` `Nullean and contributors`,
  `Copyright` `Nullean`, license, icon, per-project README, `PackageTags` per project, repository and release-notes
  URLs, `PublishRepositoryUrl`, `EmbedUntrackedSources`, `ContinuousIntegrationBuild` on CI, `EnablePackageValidation`.
- One skill per package at `src/<Project>/skills/<name>/SKILL.md`, packed with `PackagePath="skills/"` (NuGet appends
  the folder itself). Write it from the **code**, not the README (READMEs drift), and compile every snippet against
  the project before committing.
- Verify: diff the `.nuspec` and file list of a package built before and after — dependencies must not change.

## 3. Release from the release-drafter draft (label `ci`)

- `scripts/apply-template.sh <checkout>` adds `release-drafter.yml`, `pr-labels.yml`,
  `dependabot.yml`, `.github/release-drafter.yml` and the `releasing`, `breaking-changes`, `upgrade-deps` skills (copy
  the updated `pr` skill over the old one). `scripts/sync-labels.sh <owner/repo>` creates the labels.
- In `ci.yml`: replace the tag trigger with `release: types: [published]` and the tag release job with a `release` job
  (`if: github.event_name == 'release'`) calling the reusable `release.yml` (packs, uploads `release-packages`) plus a
  `publish` job in `ci.yml` itself using `nullean/.github/actions/nuget-publish` — nuget.org checks the token's
  `job_workflow_ref`, so a push from inside the reusable workflow is rejected (HTTP 401). Remove `release-notes` from the tool manifest and its
  build targets.
- Repos whose release must wait for bespoke gates (curb) keep releasing from `ci.yml`, triggered by
  `release: published` instead of a tag push.
- Pass `environment: nuget` to the release job only if the repo's release used it before (entities does): the
  trusted publishing policy names the environment when one was set.

## 4. Tests on TUnit + CsCheck + AwesomeAssertions (label `chore`)

- Same tests, same pass/skip counts per target framework; `global.json` gets `test.runner`. Mutate the code and
  confirm the suite fails, then revert.

## 4b. Build on Nullean.Make.Fs (label `chore`)

- Port `build/scripts` from Argu + Bullseye to [Nullean.Make.Fs](https://www.nuget.org/packages/Nullean.Make.Fs): targets
  become DU cases bound with `target [deps] { sh $"…" }` / `command { requires …; composes … }` (see its README).
- Keep the target names and behaviour: `--help` lists the same targets, `-s` still skips dependencies, `mise run ci`
  does exactly what it did. Remove Argu and Bullseye from `Directory.Packages.props`; Proc comes with Make.Fs.
- **Commands go through Proc.Fs, not the C# `ProcNet` API.** A target body is the `target [deps] { … }` shell block:
  `sh $"dotnet build -c Release"`, `let! sha = text $"git rev-parse HEAD"`, `let! files = lines $"…"`, loops over
  `lines` output, `use! _ = inDir "src"` / `withEnv [...]` instead of changing directories by hand. Helpers that
  compute a value (MinVer version, git SHA) use `shell { return! … }` / `text`, not `Proc.Start(...).ConsoleOut`.
  No `exec "dotnet" [list]` wrappers and no `open ProcNet` left in `build/scripts`. Arguments that may be empty are
  separate `if` branches or lists spliced with `{args}` — never string-concatenated.
- Repos without a build project (snapshots, cdp, terminal-images) keep calling `dotnet` from mise.

## 5. curb formatting (label `chore`)

- `.editorconfig` from the template, `curb-cli` in the tool manifest, `format`/`check` tasks, a CI check, and the
  re-format itself — always last, so behaviour PRs stay readable.
