<!--
  The root README of a nullean repository (GitHub). Keep the order; drop a section only when it truly doesn't apply.
  GitHub renders HTML, so the logo may use <picture>/<img>; the package READMEs may not (see PACKAGE-README.template.md).
-->
<p align="center">
  <img src="docs/images/<repo>-lockup.png" width="420" alt="<Product name>">   <!-- or the nullean mark if there is no lockup -->
</p>

<p align="center"><Tagline: one sentence, what it is and why you'd want it.></p>

<p align="center">
  <a href="https://www.nuget.org/packages/<PackageId>"><img src="https://img.shields.io/nuget/v/<PackageId>?style=flat-square" alt="NuGet"></a>
  <a href="https://github.com/nullean/<repo>/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/nullean/<repo>/ci.yml?branch=main&style=flat-square&label=ci" alt="CI"></a>
  <!-- only when a docs site exists: -->
  <a href="https://<site>.nullean.net"><img src="https://img.shields.io/badge/docs-<site>.nullean.net-20a0a0?style=flat-square" alt="Docs"></a>
</p>

<!-- Show it off: one image where the project has something visual (a rendered diagram, a terminal screenshot, a diff,
     before/after output). Libraries without visuals open with a short code sample instead. -->
![<What the image shows>](docs/images/<showcase>.png)

## Install

```sh
dotnet add package <PackageId>
```

## Quick start

```csharp
// 10–20 lines: the smallest useful program, copied from a test or example that compiles
```

## Packages <!-- multi-package repositories only -->

| Package | What it is | |
|---|---|---|
| [`<PackageId>`](src/<Project>/README.md) | <one line> | [![NuGet](https://img.shields.io/nuget/v/<PackageId>?style=flat-square)](https://www.nuget.org/packages/<PackageId>) |

## Learn more

- Documentation: https://<site>.nullean.net <!-- only when a docs site exists -->
- [Releases](https://github.com/nullean/<repo>/releases)
- [Contributing](https://github.com/nullean/.github/blob/main/CONTRIBUTING.md)

MIT licensed. Copyright Nullean and contributors.
