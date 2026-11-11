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
| `release.yml` | `release.yml` on `release: published` | optional per-RID assets onto the release, then NuGet trusted publishing |

Callers pin these by commit SHA. Dependabot's `github-actions` updates bump the pin.

## Releasing

Every repo releases the same way. release-drafter drafts the release from merged PR labels. **Publishing the draft**
(on github.com, from a phone, or `mise run release publish`) creates the tag and runs `release.yml`. Pushing a tag on
its own does nothing.

- In 0.x, `breaking` bumps the minor version.
- 1.0 is a manual decision, made by editing the draft's tag.
- Binary repos upload their assets after publishing, so they cannot use GitHub's immutable releases.

nuget.org's trusted publishing policy for each package must name the repo, the workflow file `release.yml` and the
environment `nuget`.

## Files every repo carries (`template/`)

- `mise.toml`: reads the SDK from `global.json`, and gives the same `mise run` tasks everywhere: `setup`, `build`,
  `test`, `format`, `check`, `pack`, `docs`, `clean`, `ci`, `release`.
- `global.json`: .NET 11, Microsoft.Testing.Platform.
- `.editorconfig`: curb's. Change it here, never in a repo.
- `.github/`: caller workflows, `release-drafter.yml` (0.x rules), `dependabot.yml`.
- `.claude/skills/`: `commit`, `issue`, `pr`, `release`, `breaking-changes`, `upgrade-deps`, `format`.

```bash
scripts/apply-template.sh ~/Projects/proc            # copy what is missing, pinned to this repo's HEAD
scripts/apply-template.sh ~/Projects/proc --force    # overwrite too (review the diff)
scripts/sync-labels.sh nullean/proc                  # create/update the release labels in labels.yml
```

## MSBuild baseline (`standards/`)

- `Directory.Build.props`: language settings, CPM, artifacts output, MinVer, strong naming, package metadata, and
  packing each project's `README.md`, the org icon and `skills/**` into the package.
- `tests.Directory.Build.props`: TUnit, CsCheck and AwesomeAssertions.
- `SKILL.template.md`: the shape of the small agent skill each package ships (see
  [delivering skills in NuGet packages](https://devblogs.microsoft.com/dotnet/delivering-skills-in-nuget-packages/)).
