#!/usr/bin/env bash
# Make a repository's release labels match labels.yml: create or update each one.
# Labels not in labels.yml are listed, not deleted; pass --prune to delete them.
#   scripts/sync-labels.sh nullean/proc [--prune]
set -euo pipefail

repo="${1:?usage: sync-labels.sh <owner/repo> [--prune]}"
prune="${2:-}"
here="$(cd "$(dirname "$0")/.." && pwd)"

wanted=$(yq -o=json "." "$here/labels.yml")
count=$(jq length <<<"$wanted")

i=0
while [ "$i" -lt "$count" ]; do
  name=$(jq -r ".[$i].name" <<<"$wanted")
  color=$(jq -r ".[$i].color" <<<"$wanted")
  desc=$(jq -r ".[$i].description" <<<"$wanted")
  gh label create "$name" --repo "$repo" --color "$color" --description "$desc" --force >/dev/null
  echo "ok      $name"
  i=$((i + 1))
done

names=$(jq -r '.[].name' <<<"$wanted")
gh label list --repo "$repo" --limit 200 --json name --jq '.[].name' | while IFS= read -r existing; do
  if ! grep -qxF "$existing" <<<"$names"; then
    if [ "$prune" = "--prune" ]; then
      gh label delete "$existing" --repo "$repo" --yes >/dev/null
      echo "deleted $existing"
    else
      echo "extra   $existing (kept; --prune deletes it)"
    fi
  fi
done
