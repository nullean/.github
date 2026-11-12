#!/usr/bin/env bash
# Pin every third-party `uses: owner/repo[/path]@<sha> # vX` under the given directories to the latest release of that
# action, as a full commit SHA with the tag as comment. nullean/.github refs are left alone (they move with its tags).
#   scripts/bump-actions.sh <dir>...        (needs GH_TOKEN or a logged-in gh)
set -euo pipefail
[ "$#" -gt 0 ] || { echo "usage: bump-actions.sh <dir>..." >&2; exit 1; }
files=$(grep -rlE 'uses: [^ ]+@[0-9a-f]{40}' "$@" --include='*.yml' --include='*.yaml' || true)
[ -n "$files" ] || exit 0
actions=$(grep -hoE 'uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[^@ ]+)?@[0-9a-f]{40}' $files | sed -E 's/uses: ([^/]+\/[^/@]+).*/\1/' | grep -v '^nullean/' | sort -u)
for a in $actions; do
  tag=$(gh api "repos/$a/releases/latest" --jq .tag_name 2>/dev/null || true)
  if [ -z "$tag" ]; then
    tag=$(gh api "repos/$a/tags?per_page=100" --jq '[.[].name|select(test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$"))]|first' 2>/dev/null || true)
  fi
  [ -n "$tag" ] && [ "$tag" != "null" ] || { echo "skip $a: no release" >&2; continue; }
  sha=$(gh api "repos/$a/commits/$tag" --jq .sha)
  for f in $files; do
    sed -i.bak -E "s#(uses: $a(/[^@ ]+)?)@[0-9a-f]{40}( *\#[^\n]*)?#\1@$sha \# $tag#" "$f" && rm -f "$f.bak"
  done
  echo "$a -> $tag $sha"
done
