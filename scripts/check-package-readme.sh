#!/usr/bin/env bash
# Fail when a package's README would not render on nuget.org. Usage: scripts/check-package-readme.sh <nupkg>...
#   - raw HTML tags (nuget.org renders CommonMark only)
#   - relative links or images (nuget.org has no repository to resolve them against)
#   - images that are SVG or not on nuget.org's allowed hosts
set -euo pipefail
allowed='^https://(raw\.githubusercontent\.com|raw\.github\.com|img\.shields\.io|badgen\.net|flat\.badgen\.net|media\.githubusercontent\.com|user-images\.githubusercontent\.com|camo\.githubusercontent\.com|avatars\.githubusercontent\.com|cdn\.jsdelivr\.net|codecov\.io|github\.com/[^/]+/[^/]+/(actions/)?workflows/[^ ]+/badge\.svg)'
status=0
for pkg in "$@"; do
  readme=$(unzip -Z1 "$pkg" | grep -ixE 'readme\.md' | head -1 || true)
  if [ -z "$readme" ]; then echo "$pkg: no README.md in the package"; status=1; continue; fi
  text=$(unzip -p "$pkg" "$readme" | sed '/^```/,/^```/d')   # ignore code blocks
  problems=""
  html=$(grep -noE '<(img|picture|source|p|div|br|a|table|details|summary)[ >/]' <<<"$text" | sed 's/<!--.*//' || true)
  [ -n "$html" ] && problems="$problems\n  raw HTML: $(echo "$html" | head -3 | tr '\n' ' ')"
  links=$(grep -oE '\]\([^)]+\)' <<<"$text" | sed -E 's/^\]\(([^ )]+).*/\1/' || true)
  rel=$(grep -vE '^(https?:|mailto:|#)' <<<"$links" | grep . || true)
  [ -n "$rel" ] && problems="$problems\n  relative links: $(echo "$rel" | head -3 | tr '\n' ' ')"
  imgs=$(grep -oE '!\[[^]]*\]\([^)]+\)' <<<"$text" | sed -E 's/^!\[[^]]*\]\(([^ )]+).*/\1/' || true)
  bad=$(grep -vE "$allowed" <<<"$imgs" | grep . || true)
  [ -n "$bad" ] && problems="$problems\n  images not on nuget.org's allowed hosts: $(echo "$bad" | head -3 | tr '\n' ' ')"
  svg=$(grep -E '\.svg($|\?)' <<<"$imgs" | grep -vE 'img\.shields\.io|badgen|/badge\.svg' || true)
  [ -n "$svg" ] && problems="$problems\n  SVG images (use PNG): $(echo "$svg" | head -3 | tr '\n' ' ')"
  if [ -n "$problems" ]; then printf '%s:%b\n' "$(basename "$pkg")" "$problems"; status=1; else echo "$(basename "$pkg"): ok"; fi
done
exit $status
