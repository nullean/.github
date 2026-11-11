#!/usr/bin/env bash
# Bring one repository's shared files in line with template/, in a checkout of it, and report what changed.
#   scripts/sync-template.sh <checkout> [--check]
#
# Synced (overwritten):  .claude/skills/{commit,issue,pr,releasing,breaking-changes,upgrade-deps,format}/SKILL.md,
#                        .claude/skills/writing-style.md, .github/workflows/{pr-labels,dependabot-automerge}.yml
# .editorconfig:         everything before the line `# --- repo-specific overrides` is replaced with the template;
#                        the repo's override block after it is kept. A repo whose file differs but has no marker is
#                        reported and left alone, so no repo-specific section is lost.
# .gitattributes:        created when missing; otherwise only the `* text=auto eol=lf` line is ensured.
# releasing skill:       only synced when AGENTS.md has a "Releasing" section, where repo specifics belong.
# --check:               change nothing; exit 1 if anything would change (the drift workflow uses this).
set -euo pipefail

target="${1:?usage: sync-template.sh <checkout> [--check]}"
mode="${2:-}"
target="$(cd "$target" && pwd)"
here="$(cd "$(dirname "$0")/.." && pwd)"
template="$here/template"
sha="${NULLEAN_GITHUB_SHA:-$(git -C "$here" rev-parse HEAD)}"
ref="${NULLEAN_GITHUB_REF:-$(git -C "$here" describe --tags --exact-match "$sha" 2>/dev/null || true)}"
if [ -z "$ref" ]; then
  echo "tag $sha first (or set NULLEAN_GITHUB_REF): workflow pins need a version comment" >&2
  exit 1
fi

drift=0
note() { echo "$1"; drift=1; }

render() { sed -e "s/__NULLEAN_GITHUB_SHA__/$sha/g" -e "s/__NULLEAN_GITHUB_REF__/$ref/g" "$1"; }

sync_file() {
  local rel="$1" want
  want=$(render "$template/$rel")
  if [ -f "$target/$rel" ] && [ "$(cat "$target/$rel")" = "$want" ]; then
    return
  fi
  note "sync    $rel"
  if [ "$mode" != "--check" ]; then
    mkdir -p "$(dirname "$target/$rel")"
    printf '%s\n' "$want" > "$target/$rel"
  fi
}

for skill in commit issue pr breaking-changes upgrade-deps format; do
  sync_file ".claude/skills/$skill/SKILL.md"
done
sync_file ".claude/skills/writing-style.md"
if [ ! -f "$target/.github/release-drafter.yml" ]; then
  :   # repositories that don't release (e.g. a website) carry no releasing skill
elif grep -qE '^#+ Releasing' "$target/AGENTS.md" 2>/dev/null; then
  sync_file ".claude/skills/releasing/SKILL.md"
else
  note "skip    .claude/skills/releasing/SKILL.md (AGENTS.md has no Releasing section for the repo's specifics)"
fi
for wf in pr-labels dependabot-automerge; do
  if [ "$wf" = pr-labels ] && [ ! -f "$target/.github/workflows/pr-labels.yml" ] && [ ! -f "$target/.github/release-drafter.yml" ]; then
    continue   # repositories that don't release (e.g. a website) carry no release-label check
  fi
  sync_file ".github/workflows/$wf.yml"
done

# .editorconfig: shared part from the template, repo override block kept
marker='# --- repo-specific overrides'
shared=$(cat "$template/.editorconfig")
if [ -f "$target/.editorconfig" ]; then
  if grep -qF "$marker" "$target/.editorconfig"; then
    overrides=$(sed -n "/^$marker/,\$p" "$target/.editorconfig")
    want=$(printf '%s\n\n%s' "$shared" "$overrides")
  else
    want="$shared"
  fi
  if [ "$(cat "$target/.editorconfig")" != "$want" ]; then
    if grep -qF "$marker" "$target/.editorconfig" || [ "$(cat "$target/.editorconfig")" = "$shared" ]; then
      note "sync    .editorconfig (override block kept)"
      [ "$mode" != "--check" ] && printf '%s\n' "$want" > "$target/.editorconfig"
    else
      note "REVIEW  .editorconfig differs and has no '$marker' line; move its own sections under that marker by hand"
    fi
  fi
else
  sync_file ".editorconfig"
fi

# .gitattributes
if [ ! -f "$target/.gitattributes" ]; then
  sync_file ".gitattributes"
elif ! grep -qE '^\* +text=auto +eol=lf' "$target/.gitattributes"; then
  note "sync    .gitattributes (add * text=auto eol=lf)"
  if [ "$mode" != "--check" ]; then
    { printf '* text=auto eol=lf\n'; cat "$target/.gitattributes"; } > "$target/.gitattributes.new"
    mv "$target/.gitattributes.new" "$target/.gitattributes"
  fi
fi

if [ "$drift" = 0 ]; then echo "in sync with template ($ref)"; fi
if [ "$mode" = "--check" ] && [ "$drift" = 1 ]; then exit 1; fi
exit 0
