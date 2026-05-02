#!/usr/bin/env bash
# docs-sync-from-wiki.sh — Phase 2 of the wiki-as-SoT migration.
#
# Reads from AEGIS wiki via a thin HTTP proxy (GET /api/wiki/:slug) and
# writes Astro content collection files to src/content/docs/__from-wiki/.
# Runs alongside the legacy docs-sync.sh — does NOT replace it. The output
# directory is parallel so you can compare round-trip output against the
# files produced by the legacy gh-API sync.
#
# Manifest: scripts/wiki-publish-manifest.json (slug → Astro page cosmetics).
# Source: AEGIS wiki via $AEGIS_BASE/api/wiki/:slug — auth via AEGIS_TOKEN.
#
# Usage:
#   AEGIS_TOKEN=... ./scripts/docs-sync-from-wiki.sh                  # sync all
#   AEGIS_TOKEN=... ./scripts/docs-sync-from-wiki.sh --dry-run        # show what would change
#   AEGIS_TOKEN=... ./scripts/docs-sync-from-wiki.sh --slug <slug>    # sync just one page
#
# Environment:
#   AEGIS_TOKEN    — required; AEGIS HTTP API auth token
#   AEGIS_BASE     — optional override of base URL (default: from manifest)
#
# See: AEGIS wiki `wiki-as-docs-sot-migration` for the full migration plan.
# Phase 2 = this script + parallel output dir; later phases retire the legacy sync.
#
# REQUIRES: AEGIS HTTP wiki proxy endpoint (GET /api/wiki/:slug returning the
# wiki_read shape: { page: { title, summary, body, last_verified, ... } }).
# That endpoint is filed as a follow-up dependency on aegis-daemon. Until it
# lands, the script will exit 1 with a 404 from AEGIS — proof-of-concept
# files in the output dir are pre-generated for review.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="${PROJECT_ROOT}/scripts/wiki-publish-manifest.json"

DRY_RUN=false
SLUG_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --slug)    SLUG_FILTER="$2"; shift 2 ;;
    *)         echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] + $*"; }
skip() { echo "[$(date '+%H:%M:%S')] ~ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ! $*" >&2; }

if [[ ! -f "$MANIFEST" ]]; then
  fail "Manifest not found: ${MANIFEST}"
  exit 1
fi

if [[ -z "${AEGIS_TOKEN:-}" ]]; then
  fail "AEGIS_TOKEN not set. Required for AEGIS HTTP API access."
  exit 1
fi

AEGIS_BASE="${AEGIS_BASE:-$(python3 -c "import json; print(json.load(open('$MANIFEST'))['aegisBase'])")}"
CONTENT_DIR="${PROJECT_ROOT}/$(python3 -c "import json; print(json.load(open('$MANIFEST'))['contentDir'])")"

mkdir -p "$CONTENT_DIR"

log "Wiki sync starting (Phase 2 parallel)"
log "Manifest: $MANIFEST"
log "Content dir: $CONTENT_DIR"
log "AEGIS base: $AEGIS_BASE"
$DRY_RUN && log "(dry-run mode — no files will be written)"

SYNCED=0
SKIPPED=0
FAILED=0

# Iterate manifest pages
while IFS=$'\t' read -r slug page section order color tag; do

  if [[ -n "$SLUG_FILTER" && "$slug" != "$SLUG_FILTER" ]]; then
    continue
  fi

  log "Fetching wiki: $slug → $page"

  response=$(curl -sS -m 15 \
    -H "Authorization: Bearer $AEGIS_TOKEN" \
    -w "\n__HTTP__%{http_code}" \
    "${AEGIS_BASE}/api/wiki/${slug}" 2>&1) || {
    fail "  curl failed for $slug"
    FAILED=$((FAILED + 1))
    continue
  }

  http_code=$(echo "$response" | tail -1 | sed 's/__HTTP__//')
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    fail "  HTTP $http_code from AEGIS for slug $slug"
    fail "  body: $(echo "$body" | head -c 300)"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Parse JSON: extract title, summary, body, last_verified.
  # Tolerate either response shape:
  #   { page: { title, ... } }  — original aegis#582 spec
  #   { title, ... }             — aegis-daemon v2.10.6 actually returns the page directly
  parsed=$(echo "$body" | python3 -c "
import json, sys
data = json.load(sys.stdin)
page = data.get('page', data) if isinstance(data, dict) else {}
print('---TITLE---')
print(page.get('title', ''))
print('---SUMMARY---')
print(page.get('summary', ''))
print('---LAST_VERIFIED---')
print(page.get('last_verified', ''))
print('---BODY---')
print(page.get('body', ''))
" 2>&1)

  title=$(echo "$parsed" | sed -n '/^---TITLE---$/,/^---SUMMARY---$/p' | sed '1d;$d')
  summary=$(echo "$parsed" | sed -n '/^---SUMMARY---$/,/^---LAST_VERIFIED---$/p' | sed '1d;$d')
  last_verified=$(echo "$parsed" | sed -n '/^---LAST_VERIFIED---$/,/^---BODY---$/p' | sed '1d;$d')
  page_body=$(echo "$parsed" | sed -n '/^---BODY---$/,$p' | sed '1d')

  # Build Astro frontmatter from wiki metadata + manifest cosmetics
  frontmatter=$(cat <<FRONTMATTER
---
title: "$(echo "$title" | sed 's/"/\\"/g')"
description: "$(echo "$summary" | head -c 280 | sed 's/"/\\"/g' | tr '\n' ' ')"
section: "$section"
order: $order
color: "$color"
tag: "$tag"
lastVerified: "$last_verified"
sourceSlug: "$slug"
---
FRONTMATTER
)

  full_content="${frontmatter}

${page_body}"

  out_path="${CONTENT_DIR}/${page}"

  # Compare with existing
  if [[ -f "$out_path" ]]; then
    existing_hash=$(md5sum "$out_path" | cut -d' ' -f1)
    new_hash=$(echo "$full_content" | md5sum | cut -d' ' -f1)
    if [[ "$existing_hash" == "$new_hash" ]]; then
      skip "No changes: $page"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  if $DRY_RUN; then
    ok "Would write: $page (from wiki:$slug)"
  else
    echo "$full_content" > "$out_path"
    ok "Wrote: $page (from wiki:$slug, last_verified=$last_verified)"
  fi
  SYNCED=$((SYNCED + 1))

done < <(python3 -c "
import json
m = json.load(open('$MANIFEST'))
for p in m['pages']:
    print(f\"{p['slug']}\t{p['page']}\t{p['section']}\t{p['order']}\t{p['color']}\t{p['tag']}\")
")

log ""
log "Wiki sync complete: $SYNCED updated, $SKIPPED unchanged, $FAILED failed"
$DRY_RUN && log "(dry-run — no files written)"

exit $FAILED
