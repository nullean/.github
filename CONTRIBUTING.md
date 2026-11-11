# Contributing

Thanks for helping out. Every nullean repository works the same way:

- `mise install` sets up the toolchain (the .NET SDK pinned in `global.json`, plus the tools the repository needs).
- `mise run ci` runs exactly what CI runs. `mise tasks ls` lists the rest (`build`, `test`, `format`, `check`, `pack`).
- `mise run format` formats C# with [curb](https://curb.nullean.net); CI fails on unformatted code.
- Each pull request carries **exactly one** release label (`breaking`, `feature`, `enhancement`, `bug`, `fix`,
  `documentation`, `chore`, `dependencies`, `ci` or `changelog:skip`). It decides the next version, and a check fails
  without it.
- The repository's `AGENTS.md` describes its layout and rules; it applies to people as much as to agents.

Pull requests are squash-merged, so the pull request title becomes the commit and the release-notes line: write it as
what changed, in plain words.
