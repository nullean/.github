#!/usr/bin/env bash
# Copy the nullean template into a repository checkout, pinning the reusable workflows to this repo's HEAD commit.
# Files that already exist are left alone unless --force is given (the checkout is git, so an overwrite is a diff to review); nothing is deleted.
#   scripts/apply-template.sh ~/Projects/proc [--force]
set -euo pipefail

target="${1:?usage: apply-template.sh <repo checkout> [--force]}"
target="$(cd "$target" && pwd)" # absolute: the copy loop runs from inside template/
force="${2:-}"
here="$(cd "$(dirname "$0")/.." && pwd)"
sha="${NULLEAN_GITHUB_SHA:-$(git -C "$here" rev-parse HEAD)}"
# the version comment next to each pin must name a tag that points at that commit (zizmor checks it)
ref="${NULLEAN_GITHUB_REF:-$(git -C "$here" describe --tags --exact-match "$sha" 2>/dev/null || true)}"
if [ -z "$ref" ]; then
  echo "tag $sha first (or set NULLEAN_GITHUB_REF): pins need a version comment" >&2
  exit 1
fi

cd "$here/template"
find . -type f | sed 's|^\./||' | sort | while IFS= read -r f; do
  dest="$target/$f"
  if [ -e "$dest" ] && [ "$force" != "--force" ]; then
    echo "exists  $f"
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  sed -e "s/__NULLEAN_GITHUB_SHA__/$sha/g" -e "s/__NULLEAN_GITHUB_REF__/$ref/g" "$f" > "$dest"
  echo "wrote   $f"
done
