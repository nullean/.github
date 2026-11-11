<!--
  A package README, packed from src/<Project>/README.md and rendered on nuget.org. nuget.org renders CommonMark only:
  - no raw HTML (no <img>, <picture>, <p align>), no SVG;
  - every link and image absolute; images only from nuget.org's allowed hosts — use
    https://raw.githubusercontent.com/nullean/<repo>/main/... for repository images and https://img.shields.io for badges;
  - no links to other files in the repository by relative path.
  scripts/check-package-readme.sh <nupkg> enforces these.
-->
# <PackageId>

![<Product name>](https://raw.githubusercontent.com/nullean/<repo>/main/docs/images/<repo>-lockup.png) <!-- PNG, optional -->

<Tagline: the same sentence as the root README, narrowed to this package.>

[![NuGet](https://img.shields.io/nuget/v/<PackageId>?style=flat-square)](https://www.nuget.org/packages/<PackageId>)

## Install

```sh
dotnet add package <PackageId>
```

## Quick start

```csharp
// the smallest useful use of *this* package
```

## Learn more

- Documentation: https://<site>.nullean.net <!-- only when a docs site exists -->
- Source and issues: https://github.com/nullean/<repo>
