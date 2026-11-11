#!/usr/bin/env bash
# Apply the nullean GitHub settings to one repository, from repos.yml plus the defaults below. Safe to re-run.
#   scripts/apply-repo-settings.sh <repo> [--dry-run]
#
# Shared by every repository:
#   squash merge only (PR title + body), delete branch on merge, auto-merge, update branch;
#   wiki, projects and discussions off;
#   secret scanning + push protection, Dependabot alerts + security updates, private vulnerability reporting;
#   one active ruleset `main` on the default branch: no deletion, no force-push, PRs (0 approvals, squash only),
#   required checks release-label + zizmor + the repo's `checks`; other rulesets and classic protection removed;
#   labels pruned to labels.yml.
# Per repository (repos.yml): homepage, topics, checks, immutable (default true), release-label (default true).
set -euo pipefail

repo="${1:?usage: apply-repo-settings.sh <repo> [--dry-run]}"
dry="${2:-}"
here="$(cd "$(dirname "$0")/.." && pwd)"
full="nullean/$repo"

cfg=$(yq -o=json ".\"$repo\"" "$here/repos.yml")
if [ "$cfg" = "null" ]; then
  echo "$repo is not in repos.yml" >&2
  exit 1
fi

run() {
  if [ "$dry" = "--dry-run" ]; then echo "would: $*"; else "$@"; fi
}

homepage=$(jq -r '.homepage // ""' <<<"$cfg")
immutable=$(jq -r 'if .immutable == false then "false" else "true" end' <<<"$cfg")
release_label=$(jq -r 'if ."release-label" == false then "false" else "true" end' <<<"$cfg")

echo "== $full: repository settings"
jq -n --arg homepage "$homepage" '{
  allow_squash_merge: true, allow_merge_commit: false, allow_rebase_merge: false,
  squash_merge_commit_title: "PR_TITLE", squash_merge_commit_message: "PR_BODY",
  delete_branch_on_merge: true, allow_auto_merge: true, allow_update_branch: true,
  has_wiki: false, has_projects: false, has_discussions: false,
  homepage: $homepage,
  security_and_analysis: {
    secret_scanning: {status: "enabled"},
    secret_scanning_push_protection: {status: "enabled"}
  }
}' > "${TMPDIR:-/tmp}/repo-settings-$repo.json"
run gh api -X PATCH "repos/$full" --input "${TMPDIR:-/tmp}/repo-settings-$repo.json" --silent

echo "== $full: topics"
jq '{names: .topics}' <<<"$cfg" > "${TMPDIR:-/tmp}/repo-topics-$repo.json"
run gh api -X PUT "repos/$full/topics" --input "${TMPDIR:-/tmp}/repo-topics-$repo.json" --silent

echo "== $full: security features"
run gh api -X PUT "repos/$full/vulnerability-alerts" --silent
run gh api -X PUT "repos/$full/automated-security-fixes" --silent
run gh api -X PUT "repos/$full/private-vulnerability-reporting" --silent

if [ "$immutable" = "true" ]; then
  echo "== $full: immutable releases"
  run gh api -X PUT "repos/$full/immutable-releases" --silent || echo "   (immutable releases not available for $full)"
fi

echo "== $full: ruleset main"
jq -n --argjson cfg "$cfg" --arg rl "$release_label" '
  ([ (if $rl == "true" then "release-label / release-label" else empty end), "zizmor / zizmor" ] + ($cfg.checks // []))
  as $checks
  | {
      name: "main", target: "branch", enforcement: "active",
      conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
      bypass_actors: [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}],
      rules: [
        {type: "deletion"},
        {type: "non_fast_forward"},
        {type: "pull_request", parameters: {
          required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
          require_code_owner_review: false, require_last_push_approval: false,
          required_review_thread_resolution: false, allowed_merge_methods: ["squash"]}},
        {type: "required_status_checks", parameters: {
          strict_required_status_checks_policy: false, do_not_enforce_on_create: true,
          required_status_checks: ($checks | map({context: .}))}}
      ]
    }' > "${TMPDIR:-/tmp}/repo-ruleset-$repo.json"
existing=$(gh api "repos/$full/rulesets" --jq '.[] | "\(.id)\t\(.name)"')
main_id=$(awk -F'\t' '$2=="main"{print $1; exit}' <<<"$existing")
if [ -n "$main_id" ]; then
  run gh api -X PUT "repos/$full/rulesets/$main_id" --input "${TMPDIR:-/tmp}/repo-ruleset-$repo.json" --silent
else
  run gh api -X POST "repos/$full/rulesets" --input "${TMPDIR:-/tmp}/repo-ruleset-$repo.json" --silent
  main_id=$(gh api "repos/$full/rulesets" --jq '.[] | select(.name=="main") | .id' 2>/dev/null || true)
fi
while IFS=$'\t' read -r id name; do
  [ -z "$id" ] && continue
  [ "$id" = "$main_id" ] && continue
  echo "   removing ruleset $id ($name)"
  run gh api -X DELETE "repos/$full/rulesets/$id" --silent
done <<<"$existing"
default_branch=$(gh api "repos/$full" --jq .default_branch)
if gh api "repos/$full/branches/$default_branch/protection" --silent 2>/dev/null; then
  echo "   removing classic branch protection on $default_branch"
  run gh api -X DELETE "repos/$full/branches/$default_branch/protection" --silent
fi

echo "== $full: labels"
if [ "$dry" = "--dry-run" ]; then
  echo "would: sync-labels.sh $full --prune (keeps only labels.yml)"
  gh label list --repo "$full" --limit 200 --json name --jq '.[].name' | grep -vxF -f <(yq -r '.[].name' "$here/labels.yml") | sed 's/^/would delete label: /' | head -5
else
  "$here/scripts/sync-labels.sh" "$full" --prune
fi
