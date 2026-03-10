#!/usr/bin/env bash
# docs-sync.sh — Stackbilt docs synchronization pipeline
#
# Pulls doc fragments from product repos via GitHub API, assembles them
# into the Astro content directory, and optionally builds + deploys.
#
# Designed to run headless via AEGIS task queue or manually.
#
# Usage:
#   ./scripts/docs-sync.sh                    # Sync all sources, build, deploy
#   ./scripts/docs-sync.sh --dry-run          # Show what would change, no writes
#   ./scripts/docs-sync.sh --sync-only        # Sync files but don't build/deploy
#   ./scripts/docs-sync.sh --source charter   # Sync only one source group
#   ./scripts/docs-sync.sh --generate         # Use headless Claude to generate missing fragments
#
# Environment:
#   GITHUB_TOKEN     — GitHub PAT for API access (required)
#   AEGIS_URL        — AEGIS endpoint for session digest (optional)
#   AEGIS_TOKEN      — Auth token for digest (optional)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="${PROJECT_ROOT}/docs-manifest.json"
CONTENT_DIR="${PROJECT_ROOT}/src/content/docs"
SYNC_STATE="${PROJECT_ROOT}/.docs-sync-state.json"

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
AEGIS_URL="${AEGIS_URL:-https://aegis.stackbilt.dev}"
AEGIS_TOKEN="${AEGIS_TOKEN:-}"

DRY_RUN=false
SYNC_ONLY=false
GENERATE=false
SOURCE_FILTER=""

# ─── Parse args ──────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=true; shift ;;
    --sync-only)   SYNC_ONLY=true; shift ;;
    --generate)    GENERATE=true; shift ;;
    --source)      SOURCE_FILTER="$2"; shift 2 ;;
    *)             echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] + $*"; }
skip() { echo "[$(date '+%H:%M:%S')] ~ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ! $*" >&2; }

# Fetch a file from GitHub API, returns content or empty string
gh_fetch_file() {
  local repo="$1" path="$2" branch="${3:-main}"
  local org
  org=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['org'])")

  local response
  response=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/${org}/${repo}/contents/${path}?ref=${branch}" \
    2>/dev/null) || true

  # Check if it's an error response (JSON with "message" field)
  if echo "$response" | python3 -c "import json,sys; json.load(sys.stdin)['message']" 2>/dev/null; then
    echo ""
    return 1
  fi

  echo "$response"
}

# Get latest commit date for a repo
gh_latest_commit() {
  local repo="$1"
  local org
  org=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['org'])")

  curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${org}/${repo}/commits?per_page=1" \
    2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['commit']['committer']['date'])" 2>/dev/null || echo "unknown"
}

# Build frontmatter from manifest page config
build_frontmatter() {
  local page_key="$1" title="$2"
  local section order color tag description

  # Extract page metadata from manifest
  read -r section order color tag description < <(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
for src in m['sources'].values():
    for pk, pv in src['pages'].items():
        if pk == '$page_key':
            # Try to extract description from title or use default
            print(pv['section'], pv['order'], pv['color'], pv['tag'], '')
            sys.exit(0)
print('platform 99 #888 99 ')
" 2>/dev/null)

  cat <<FRONTMATTER
---
title: "${title}"
description: ""
section: "${section}"
order: ${order}
color: "${color}"
tag: "${tag}"
---
FRONTMATTER
}

# ─── Validation ──────────────────────────────────────────────

if [[ ! -f "$MANIFEST" ]]; then
  fail "Manifest not found: ${MANIFEST}"
  exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
  # Try to get from git config or env
  GITHUB_TOKEN=$(git config --global github.token 2>/dev/null || echo "")
  if [[ -z "$GITHUB_TOKEN" ]]; then
    fail "GITHUB_TOKEN not set. Required for GitHub API access."
    exit 1
  fi
fi

log "Docs sync starting"
log "Manifest: ${MANIFEST}"
log "Content dir: ${CONTENT_DIR}"
$DRY_RUN && log "(dry-run mode — no files will be written)"

# ─── Sync loop ───────────────────────────────────────────────

SYNCED=0
SKIPPED=0
FAILED=0
GENERATED=0
CHANGES=()

# Parse manifest and iterate sources
# NOTE: process substitution (< <(...)) keeps the while loop in the current
# shell so counter variables (SYNCED, SKIPPED, etc.) persist after the loop.
while IFS=$'\t' read -r src_name repo page_key source_path fallback_path; do

  # Apply source filter if specified
  if [[ -n "$SOURCE_FILTER" && "$src_name" != "$SOURCE_FILTER" ]]; then
    continue
  fi

  log "Syncing: ${repo}/${source_path} → ${page_key}"

  # Try primary source path
  content=$(gh_fetch_file "$repo" "$source_path" 2>/dev/null) || content=""

  # Try fallback if primary not found
  if [[ -z "$content" && -n "$fallback_path" ]]; then
    log "  Primary not found, trying fallback: ${fallback_path}"
    content=$(gh_fetch_file "$repo" "$fallback_path" 2>/dev/null) || content=""
  fi

  if [[ -z "$content" ]]; then
    if [[ "$GENERATE" == "true" ]]; then
      # Use headless Claude to generate the doc fragment from source code
      log "  Source not found — generating via headless Claude..."

      if [[ "$DRY_RUN" == "true" ]]; then
        skip "Would generate ${page_key} from ${repo} source code"
        continue
      fi

      # Strip nesting guard for headless execution
      unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT 2>/dev/null || true

      GENERATE_PROMPT="You are generating a documentation page for the Stackbilt docs site.

Product repo: ${repo} (GitHub org: $(python3 -c "import json; print(json.load(open('$MANIFEST'))['org'])"))
Target page: ${page_key}

Instructions:
1. Use the GitHub API to explore the repo: list files, read README, read key source files
2. Understand the product's API surface, features, and usage
3. Write a comprehensive documentation page in Markdown
4. Do NOT include frontmatter — just the markdown body starting with a # heading
5. Match the style of existing Stackbilt docs: technical, concise, code examples, tables for API endpoints
6. Output ONLY the markdown content, nothing else

Focus on: what it does, how to authenticate, key endpoints/tools, code examples."

      generated=$(claude -p "$GENERATE_PROMPT" \
        --allowedTools "Bash,Read,Grep,Glob" \
        --max-turns 15 \
        --output-format text \
        2>/dev/null) || {
        fail "  Generation failed for ${page_key}"
        FAILED=$((FAILED + 1))
        continue
      }

      if [[ -n "$generated" ]]; then
        # Extract title from first heading
        title=$(echo "$generated" | grep -m1 '^# ' | sed 's/^# //')
        [[ -z "$title" ]] && title="${page_key%.md}"

        # Build full page with frontmatter
        frontmatter=$(build_frontmatter "$page_key" "$title")
        full_content="${frontmatter}

${generated}"

        echo "$full_content" > "${CONTENT_DIR}/${page_key}"
        ok "Generated: ${page_key} (from ${repo} source)"
        GENERATED=$((GENERATED + 1))
      fi
      continue
    else
      skip "Not found: ${repo}/${source_path} (use --generate to create from source)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  # Check if content has frontmatter already
  has_frontmatter=false
  if echo "$content" | head -1 | grep -q '^---$'; then
    has_frontmatter=true
  fi

  # If the source doesn't have frontmatter, preserve existing or generate it
  if [[ "$has_frontmatter" == "false" ]]; then
    existing="${CONTENT_DIR}/${page_key}"
    if [[ -f "$existing" ]]; then
      # Extract existing frontmatter and prepend to new content
      existing_fm=$(sed -n '/^---$/,/^---$/p' "$existing")
      content="${existing_fm}

${content}"
    else
      # Generate frontmatter from manifest
      title=$(echo "$content" | grep -m1 '^# ' | sed 's/^# //')
      [[ -z "$title" ]] && title="${page_key%.md}"
      fm=$(build_frontmatter "$page_key" "$title")
      content="${fm}

${content}"
    fi
  fi

  # Compare with existing
  if [[ -f "${CONTENT_DIR}/${page_key}" ]]; then
    existing_hash=$(md5sum "${CONTENT_DIR}/${page_key}" 2>/dev/null | cut -d' ' -f1)
    new_hash=$(echo "$content" | md5sum | cut -d' ' -f1)

    if [[ "$existing_hash" == "$new_hash" ]]; then
      skip "No changes: ${page_key}"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  # Write the synced content
  if [[ "$DRY_RUN" == "true" ]]; then
    ok "Would update: ${page_key} (from ${repo}/${source_path})"
  else
    echo "$content" > "${CONTENT_DIR}/${page_key}"
    ok "Synced: ${page_key} (from ${repo}/${source_path})"
  fi
  SYNCED=$((SYNCED + 1))

done < <(python3 -c "
import json
m = json.load(open('$MANIFEST'))
for src_name, src in m['sources'].items():
    for page_key, page in src['pages'].items():
        fallback = page.get('fallback', '')
        print(f'{src_name}\t{src[\"repo\"]}\t{page_key}\t{page[\"source\"]}\t{fallback}')
")

log ""
log "Sync complete: ${SYNCED} updated, ${SKIPPED} unchanged, ${FAILED} failed, ${GENERATED} generated"

if [[ "$DRY_RUN" == "true" || "$SYNC_ONLY" == "true" ]]; then
  [[ "$DRY_RUN" == "true" ]] && log "(dry-run — no files written)"
  [[ "$SYNC_ONLY" == "true" ]] && log "(sync-only — skipping build/deploy)"
  exit 0
fi

# ─── Build ───────────────────────────────────────────────────

if [[ $SYNCED -gt 0 || $GENERATED -gt 0 ]]; then
  log "Building docs site..."
  cd "$PROJECT_ROOT"
  npm run build 2>&1 | tail -5 || {
    fail "Build failed"
    exit 1
  }
  ok "Build succeeded"

  # ─── Deploy ─────────────────────────────────────────────────

  log "Deploying to Cloudflare..."
  npm run deploy 2>&1 | tail -5 || {
    fail "Deploy failed"
    exit 1
  }
  ok "Deployed to docs.stackbilt.dev"

  # ─── Record sync watermark + session digest ─────────────────

  if [[ -n "$AEGIS_TOKEN" ]]; then
    log "Recording sync watermark and session digest..."
    # Record the sync watermark so AEGIS drift detection knows when we last synced
    curl -s -m 10 -X POST "${AEGIS_URL}/api/events" \
      -H "Authorization: Bearer ${AEGIS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"event_id": "last_docs_sync_at"}' \
      2>/dev/null || true
    # Post session digest
    curl -s -m 10 -X POST "${AEGIS_URL}/api/cc-session" \
      -H "Authorization: Bearer ${AEGIS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"summary\": \"Docs sync: ${SYNCED} pages updated, ${GENERATED} generated, deployed to docs.stackbilt.dev\", \"repos\": [\"stackbilt_docs_v2\"]}" \
      2>/dev/null || true
    ok "Sync watermark and session digest posted"
  fi
else
  log "No changes detected — skipping build/deploy"
fi

log "Docs sync pipeline complete"
