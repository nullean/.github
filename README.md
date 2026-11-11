# nullean/.github

The shared standard for nullean repositories: reusable workflows, the files every repo carries, and the scripts that
put them there.

## Reusable workflows

| Workflow | Called from | Does |
|---|---|---|
| `dotnet-ci.yml` | `ci.yml` on PR and push to main | `mise run ci` on Linux, Windows and macOS; uploads packages |
| `zizmor.yml` | `ci.yml` | static analysis of the repo's workflows, fails at medium severity |
| `release-drafter.yml` | `release-drafter.yml` on push to main | keeps the next release's draft current from PR labels |
| `pr-labels.yml` | `pr-labels.yml` on PR | a PR must carry exactly one release label |
| `release.yml` | the `release` job in `ci.yml`, on `release: published` | optional per-RID assets onto the release, then packs at the tag and uploads the packages as an artifact |
| `actions/nuget-publish` | a step in the caller's own `publish` job | NuGet trusted publishing push, then appends public API reports to the notes (a composite action, so the token names the caller's `ci.yml`) |

Callers pin these by commit SHA. Dependabot's `github-actions` updates bump the pin.

## Releasing

Every repo releases the same way. release-drafter drafts the release from merged PR labels. **Publishing the draft**
(on github.com, from a phone, or `mise run release publish`) creates the tag and runs the `release` job in `ci.yml`. Pushing a tag on
its own does nothing.

- In 0.x, `breaking` bumps the minor version.
- 1.0 is a manual decision, made by editing the draft's tag.
- Binary repos upload their assets after publishing, so they cannot use GitHub's immutable releases.

nuget.org's trusted publishing policies name `ci.yml` and check the token's `job_workflow_ref`, so the push must run
in a job of the repo's own `ci.yml`: the reusable `release.yml` only packs, and the repo's `publish` job pushes with the
`actions/nuget-publish` composite action (composite actions keep the caller's workflow ref).

## Files every repo carries (`template/`)

- `mise.toml`: installs the SDK `global.json` pins (plus any extra runtimes listed after it), and gives the same `mise run` tasks everywhere: `setup`, `build`,
  `test`, `format`, `check`, `pack`, `docs`, `clean`, `ci`, `release`.
- `global.json`: .NET 11, Microsoft.Testing.Platform.
- `.editorconfig`: curb's. Change it here, never in a repo. `.gitattributes` keeps checkouts LF to match it.
- `.github/`: caller workflows, `release-drafter.yml` (0.x rules), `dependabot.yml`.
- `.claude/skills/`: `commit`, `issue`, `pr`, `releasing`, `breaking-changes`, `upgrade-deps`, `format`.

```bash
scripts/apply-template.sh ~/Projects/proc            # copy what is missing, pinned to this repo's HEAD
scripts/apply-template.sh ~/Projects/proc --force    # overwrite too (review the diff)
scripts/sync-labels.sh nullean/proc                  # create/update the release labels in labels.yml
```

## Rolling it out

[docs/rollout.md](docs/rollout.md) is the step-by-step, with what applying it to proc and curb taught us.

## MSBuild baseline (`standards/`)

- `Directory.Build.props`: language settings, CPM, artifacts output, MinVer, strong naming, package metadata, and
  packing each project's `README.md`, the org icon and `skills/**` into the package.
- `tests.Directory.Build.props`: TUnit, CsCheck and AwesomeAssertions.
- `SKILL.template.md`: the shape of the small agent skill each package ships (see
  [delivering skills in NuGet packages](https://devblogs.microsoft.com/dotnet/delivering-skills-in-nuget-packages/)).
