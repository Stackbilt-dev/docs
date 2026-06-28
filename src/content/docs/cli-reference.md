---
title: "CLI Reference"
description: "Complete command reference for Charter CLI. Every command, flag, and option for governance validation, drift detection, ADF context compilation, and codebase analysis."
section: "charter"
order: 3
color: "#f59e0b"
tag: "03"
---

# CLI Reference

Use `npx charter ...` if Charter is installed as a local dev dependency. Use `charter ...` if installed globally.

For conceptual overview and quickstart, see [Charter Kit](/getting-started). For how Charter fits into the full Stackbilt stack, see the [Ecosystem](/ecosystem) overview. The [Stackbilder platform](/platform) consumes Charter's governance output in its CI pipeline.

## Governance Commands

### charter validate

Checks commit trailers for governance compliance. Every commit should carry a `Governed-By:` trailer linking it to an ADR or governance decision.

```bash
npx charter validate                       # check recent commits
npx charter validate --ci                  # CI mode — exits 1 on violations
npx charter validate --ci --format json    # machine-readable output
npx charter validate --range HEAD~5..HEAD  # specific commit range
```

**Default range detection:** When `--range` is omitted, Charter tries `main..HEAD` or `master..HEAD` first, then falls back to the most recent 5 commits.

JSON output includes `policyOffenders` (missing required trailers) and `riskOffenders` (high-risk paths without governance), plus `effectiveRangeSource` and `defaultCommitRange` for agent transparency.

### charter drift

Scans the codebase for deviations from your blessed stack patterns. Detects unapproved dependencies, frameworks, and patterns defined in `.charter/patterns/*.json`.

```bash
npx charter drift                         # scan + print report
npx charter drift --ci --format json      # CI mode
npx charter drift --path ./packages       # scan a specific directory
```

### charter audit

Generates a governance posture report: risk score, governed commit ratio, recent violations, and trend data. Policy score uses configurable section coverage.

```bash
npx charter audit
npx charter audit --format json
npx charter audit --range HEAD~10..HEAD
```

### charter classify

Classifies a subject or change request into a governance scope.

| Scope | Meaning |
|---|---|
| `SURFACE` | UI/copy only, low risk |
| `LOCAL` | Contained to one module |
| `CROSS_CUTTING` | Touches multiple systems, requires ADR |

```bash
npx charter classify "add OAuth callback flow"
npx charter classify "migrate auth provider" --format json
```

### charter hook

Installs git hooks for commit-time governance enforcement.

```bash
npx charter hook install --commit-msg                # trailer normalization hook
npx charter hook install --pre-commit                # ADF evidence gate hook
npx charter hook install --commit-msg --pre-commit   # both hooks
npx charter hook install --commit-msg --force        # overwrite existing hooks
```

- `--commit-msg` — normalizes `Governed-By` and `Resolves-Request` trailers via `git interpret-trailers`
- `--pre-commit` — runs ADF evidence checks (LOC ceiling validation) before each commit. Only gates when `.ai/manifest.adf` exists.
- `--force` — overwrite existing non-Charter hooks

Must specify at least one of `--commit-msg` or `--pre-commit`.

### charter bootstrap

One-command repo onboarding. Orchestrates detect + setup + ADF init + install + doctor in a single flow.

```bash
npx charter bootstrap                                         # interactive
npx charter bootstrap --preset worker --ci github --yes       # fully automated
npx charter bootstrap --preset rust-wasm --ci github --yes    # Rust/WASM project
npx charter bootstrap --security-sensitive                    # security posture baseline
npx charter bootstrap --skip-install --skip-doctor            # minimal
```

- `--ci github` — generate GitHub Actions governance workflow
- `--preset <worker|frontend|backend|fullstack|docs|rust-wasm>` — stack preset
- `--security-sensitive` — generate `SECURITY.md`, seed hard-fail drift denies in `.charter/patterns/security-deny.json`, warn in `doctor` when no `security*` or `l4*` test file exists
- `--skip-install` — skip dependency installation phase
- `--skip-doctor` — skip health check phase
- `-y, --yes` — accept all prompts

### charter setup

Bootstraps `.charter/` config and optionally writes CI workflow scaffolding. For full onboarding, prefer `charter bootstrap` which orchestrates setup + ADF init + install + doctor.

```bash
npx charter setup --detect-only --format json
npx charter setup --ci github --yes
npx charter setup --preset fullstack --ci github --yes
npx charter setup --preset rust-wasm --ci github --yes
```

Setup-specific options:

- `--ci github` — generate GitHub Actions governance workflow
- `--preset <worker|frontend|backend|fullstack|docs|rust-wasm>` — stack preset
- `--detect-only` — preview detection results without writing files
- `--no-dependency-sync` — skip rewriting `@stackbilt/cli` devDependency

### charter init

Scaffolds the `.charter/` config directory without running the full setup workflow.

```bash
npx charter init
npx charter init --preset worker
```

### charter doctor

Checks CLI installation and repository config health. Validates ADF readiness: manifest existence, manifest parse, default-load module presence, sync lock status, and agent config file migration status.

```bash
npx charter doctor                    # full diagnostics
npx charter doctor --adf-only         # ADF checks only (skip Charter config)
npx charter doctor --ci --format json # CI mode: exit 1 on warnings
```

- `--adf-only` — run only ADF readiness checks, skip Charter config validation
- `--ci` — non-interactive, exits with policy violation code on warnings

#### Source LOC budgets

To cap runtime source files from quietly becoming god-objects, declare per-path LOC budgets in `.charter/config.json`. `charter doctor` measures matching files and reports:

```jsonc
{
  "locBudgets": {
    "defaultWarn": 300,
    "defaultFail": 600,
    "paths": [
      { "pattern": "src/index.ts", "warn": 200, "fail": 500, "reason": "entry should stay thin" },
      { "pattern": "src/**", "warn": 300, "fail": 600 }
    ]
  }
}
```

- Patterns match repo-relative paths. `*` within a single segment, `**` across segments. First matching rule wins — list more specific patterns first.
- A file over its `fail` ceiling is a `WARN` check — under `--ci` exits non-zero. Over `warn` but within `fail` is advisory (`INFO`) and never fails CI.
- `"enabled": false` keeps the config block without enforcing it.
- No budgets configured: `doctor` emits a soft non-blocking `INFO` nudge.

### charter why

Prints a quick explanation of Charter's governance value and adoption ROI.

```bash
npx charter why
```

### charter score

Letter-grade AI-readiness audit across six dimensions: agent config, grounding, architecture, testing, governance, and freshness.

```bash
npx charter score                  # print letter-grade audit
npx charter score --badge --write  # emit shields.io payload → .charter/badge.json
```

`--badge --write` emits a [shields.io endpoint](https://shields.io/badges/endpoint-badge) payload for use in README badges:

```json
{"schemaVersion":1,"label":"agent context","message":"A (92)","color":"brightgreen"}
```

Grade color scale: A = brightgreen, B = green, C = yellowgreen, D = yellow, F = red.

To add the badge to your README (replace `<org>`, `<repo>`, `<branch>`):

```markdown
[![Agent context](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2F<org>%2F<repo>%2F<branch>%2F.charter%2Fbadge.json)](https://github.com/Stackbilt-dev/charter)
```

---

## ADF Commands

ADF (Attention-Directed Format) is Charter's modular AI context compiler. These commands manage the `.ai/` directory.

### charter adf init

Scaffolds `.ai/` directory with preset-aware modules. The scaffolded `core.adf` includes a `[load-bearing]` CONSTRAINTS section and a `METRICS [load-bearing]` section with starter LOC ceilings.

```bash
npx charter adf init
npx charter adf init --ai-dir ./context       # custom directory
npx charter adf init --force                  # overwrite existing
npx charter adf init --emit-pointers          # generate thin pointer files
npx charter adf init --module testing         # add a single module to existing .ai/
```

- `--ai-dir <dir>` — custom directory path (default: `.ai`). Resolved to an absolute path at runtime.
- `--force` — overwrite existing files. Without this flag, existing `.adf` files are skipped; only missing `manifest.adf` is written.
- `--emit-pointers` — generate thin pointer files (`CLAUDE.md`, `.cursorrules`, `agents.md`). Generated `CLAUDE.md` includes a `## Session Start` section with guidance to call `charter_context` MCP tool at session start.
- `--module <name>` — add a single module to existing `.ai/` (delegates to `adf create`)

**Default scaffolding** (worker/frontend/backend/fullstack presets):

| File | Purpose |
|------|---------|
| `manifest.adf` | Module registry with default-load and on-demand routing |
| `core.adf` | Universal constraints, metrics, and project context |
| `state.adf` | Current session state |
| `frontend.adf` | Frontend module scaffold (triggers: React, CSS, UI) |
| `backend.adf` | Backend module scaffold (triggers: API, Node, DB) |

**Docs preset** (`--preset docs`):

| File | Purpose |
|------|---------|
| `manifest.adf` | Docs-specific module routing |
| `core.adf` | Universal constraints and metrics |
| `state.adf` | Current session state |
| `decisions.adf` | ADR and decision tracking (triggers: ADR, decision, rationale) |
| `planning.adf` | Roadmap and milestone tracking (triggers: plan, milestone, phase, roadmap) |

**Rust/WASM preset** (`--preset rust-wasm`):

| File | Purpose |
|------|---------|
| `manifest.adf` | Rust/WASM-specific routing (triggers: Cargo, WASM, wasm-pack, wasm-bindgen, cdylib, wasm32) |
| `core.adf` | Universal constraints and metrics |
| `state.adf` | Current session state |
| `rust-wasm.adf` | Library constraints: pure exports, dual crate-type, wasm-pack build/test gates, `pkg/` publish boundary |

`charter bootstrap --preset rust-wasm` also scaffolds: `Cargo.toml` (cdylib + rlib), `src/lib.rs`, `tests/integration.rs`, root `package.json`, `.gitignore`, and `.github/workflows/ci.yml` (Rust toolchain + wasm32 target + wasm-pack test + build steps).

### charter adf create

Creates a new ADF module file and registers it in the manifest under `DEFAULT_LOAD` or `ON_DEMAND`.

```bash
npx charter adf create api-patterns                           # on-demand module (default)
npx charter adf create core-rules --load default              # default-load module
npx charter adf create react --triggers "react,jsx,component" # on-demand with triggers
npx charter adf create api-patterns --force                   # overwrite existing
```

- `--load <default|on-demand>` — loading policy (default: `on-demand`)
- `--triggers "a,b,c"` — comma-separated trigger keywords (for on-demand modules)
- `--ai-dir <dir>` — path to ADF directory (default: `.ai`)
- `--force` — overwrite existing module file

### charter adf migrate

Scans existing agent config files (`CLAUDE.md`, `.cursorrules`, `agents.md`, `GEMINI.md`, `copilot-instructions.md`), classifies their content, and migrates structured blocks into ADF modules. Replaces originals with thin pointers.

```bash
npx charter adf migrate --dry-run                # preview migration plan
npx charter adf migrate --yes                    # execute migration
npx charter adf migrate --source CLAUDE.md       # migrate a single file
npx charter adf migrate --merge-strategy replace # overwrite existing sections
npx charter adf migrate --no-backup              # skip .pre-adf-migrate.bak files
```

- `--dry-run` — preview changes without writing files
- `--source <file>` — migrate a specific file instead of scanning all
- `--merge-strategy <append|dedupe|replace>` — how to handle duplicates (default: `dedupe`)
- `--no-backup` — skip creating backup files
- `--ai-dir <dir>` — path to ADF directory (default: `.ai`)

### charter adf compile

Renders `.ai/` ADF modules into vendor-specific config files. ADF is the source of truth; vendor files (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `GEMINI.md`) are build artifacts.

```bash
npx charter adf compile --target claude        # render CLAUDE.md to stdout
npx charter adf compile --target all --write   # write all vendor files
npx charter adf compile --target all --check   # CI drift gate: exit 1 if any vendor file is stale
```

- `--target <claude|codex|cursor|gemini|all>` — which vendor file(s) to compile
- `--write` — write to disk instead of stdout
- `--check` — CI mode: compare compiled output to existing files, exit 1 if stale

Use `--check` in CI to catch hand-edits to generated vendor files before they drift from the ADF source. Edit `.ai/` once, compile for all targets.

### charter adf fmt

Parses and reformats ADF files to canonical form. Enforces emoji decorations, canonical section ordering, and 2-space indent.

```bash
npx charter adf fmt .ai/core.adf --write   # reformat in-place
npx charter adf fmt .ai/core.adf --check   # CI: exit 1 if not canonical
```

### charter adf patch

Applies typed delta operations to ADF files. Agents issue patches instead of rewriting entire files — preventing silent memory corruption.

```bash
npx charter adf patch .ai/state.adf --ops '[{"op":"ADD_BULLET","section":"STATE","value":"Reviewing PR #42"}]'
npx charter adf patch .ai/state.adf --ops-file patches.json
```

**Operations:** `ADD_BULLET`, `REPLACE_BULLET`, `REMOVE_BULLET`, `ADD_SECTION`, `REPLACE_SECTION`, `REMOVE_SECTION`, `UPDATE_METRIC`.

With `--format json`, output includes a `changes[]` array with per-op before/after values.

### charter adf bundle

Resolves manifest modules for a given task and outputs merged context with token estimate. Only loads modules whose trigger keywords match the task.

```bash
npx charter adf bundle --task "Fix the React login component"
npx charter adf bundle --task "Add REST endpoint" --format json
```

JSON output includes `triggerMatches` (with `matchedKeywords` and `loadReason`), `unmatchedModules`, `tokenEstimate`, `tokenBudget`, `tokenUtilization`, and `perModuleTokens`.

### charter adf sync

Verifies source `.adf` files match locked hashes, or updates the lock file.

```bash
npx charter adf sync --check               # CI: exit 1 on drift
npx charter adf sync --write               # update .adf.lock
npx charter adf sync --check --format json
```

### charter adf evidence

Validates metric constraints and produces a structured evidence report. The core of Charter's ADF governance pipeline.

```bash
npx charter adf evidence --auto-measure                     # full report
npx charter adf evidence --auto-measure --ci --format json  # CI gating
npx charter adf evidence --task "auth module" --auto-measure
npx charter adf evidence --context '{"entry_loc": 142}'
npx charter adf evidence --context-file metrics.json
```

**`--auto-measure`** counts lines in source files referenced by the manifest `METRICS` section and injects them as context overrides.

**Constraint semantics:** `value < ceiling` = pass, `value === ceiling` = warn, `value > ceiling` = fail.

**CI mode:** exits 1 on any constraint failure. Warnings (at boundary) surface in the report but do not fail the build.

Output includes constraint results, weight summary (load-bearing / advisory / unweighted), sync status, advisory-only warnings, and a `nextActions` array.

### charter adf metrics recalibrate

Recalibrates metric baselines and ceilings from current measured LOC. Requires a rationale for every recalibration to maintain audit trail.

```bash
npx charter adf metrics recalibrate --auto-rationale                   # auto-generate rationale
npx charter adf metrics recalibrate --reason "post-refactor baseline"  # custom rationale
npx charter adf metrics recalibrate --headroom 20 --dry-run            # preview with 20% headroom
npx charter adf metrics recalibrate --auto-rationale --format json     # machine-readable
```

- `--headroom <percent>` — percentage above current LOC for ceiling calculation (default: `15`, range: 1–200)
- `--reason "<text>"` — required rationale text (mutually exclusive with `--auto-rationale`)
- `--auto-rationale` — auto-generate rationale from headroom and metric count
- `--dry-run` — preview recalibration without writing files
- `--ai-dir <dir>` — custom `.ai/` directory (default: `.ai`)

**Behavior:** Calculates new ceilings as `ceil(current × (1 + headroom / 100))` and appends entries to `BUDGET_RATIONALES`:

```
{metric}_{ISO_DATE}: {old} -> {new}, ceiling {oldCeiling} -> {newCeiling}; {rationale}
```

One of `--reason` or `--auto-rationale` is required.

---

## Analyze Commands

### charter blast

Compute the blast radius of a change: which files transitively depend on the given seed files?

```bash
npx charter blast src/kernel/dispatch.ts                    # default depth 3
npx charter blast src/a.ts src/b.ts --depth 4               # multi-seed, custom depth
npx charter blast src/foo.ts --format json                  # structured output
npx charter blast src/foo.ts --root ./packages/server       # scan a subdirectory
```

- `<file>` — one or more seed file paths (required, positional)
- `--depth <n>` — max BFS depth through the reverse dependency graph (default: `3`)
- `--root <dir>` — project root to scan (default: `.`)
- `--format json` — structured JSON output

**Output includes:** `affected` (files that transitively import the seeds), `hotFiles` (top 20 most-imported architectural hubs), `summary.totalAffected`, `summary.seedCount`, `summary.depthHistogram`.

**Governance signal:** blast radius ≥20 files triggers a `CROSS_CUTTING` warning — escalate wide-reaching changes to architectural review.

Deterministic, zero runtime dependencies, no LLM calls. Auto-detects tsconfig path aliases including monorepo `@scope/package` imports.

### charter surface

Extract the API surface of a project: HTTP routes and database schema tables.

```bash
npx charter surface                                 # text summary
npx charter surface --format json                   # machine-readable
npx charter surface --markdown                      # for .ai/surface.adf injection
npx charter surface --root ./packages/worker        # scan a subdirectory
npx charter surface --schema db/schema.sql          # explicit schema path
```

- `--root <dir>` — project root to scan (default: `.`)
- `--schema <path>` — explicit schema SQL file (default: auto-detect `*schema*.sql`)
- `--markdown` / `--md` — emit markdown for `.ai/surface.adf` or agent brief injection
- `--format json` — structured JSON

**Detects:** Hono, Express, itty-router routes; D1/SQLite `CREATE TABLE` statements with column types and flags. Ignores test files.

**Use cases:** breaking-change detection (diff JSON before/after PR), auto-generating `.ai/surface.adf` context, mission brief fingerprinting for autonomous task runners.

---

## charter serve

Expose ADF project context as an MCP server over stdio, for use with Claude Code, Codex, and Cursor.

```bash
npx charter serve                             # stdio MCP server (default)
npx charter serve --ai-dir /abs/path/.ai      # explicit ADF directory
npx charter serve --name "my-project"         # override the server name
```

- `--ai-dir <dir>` — path to the `.ai/` ADF directory (default: `.ai`). **Always resolved to an absolute path at startup.**
- `--name <name>` — override the MCP server name (default: inferred from `core.adf` `PROJECT` section or directory name)

### Wiring in `.mcp.json`

```json
{
  "mcpServers": {
    "charter": {
      "command": "npx",
      "args": ["@stackbilt/cli", "serve", "--ai-dir", "/absolute/path/to/.ai"]
    }
  }
}
```

Use an absolute path for `--ai-dir`. A relative path resolves against the MCP host's working directory at spawn time, which may not be the project root.

### Registered MCP tools

| Tool | Description |
|------|-------------|
| `charter_brief` | **Call first.** Pre-digested repo brief — routes, hotspots, governance. Replaces 15–30 cold-boot discovery calls. |
| `charter_context` | Session continuity snapshot reader/refresher (`.ai/context.snapshot.json`). Use `refresh=true` to run `context-refresh` before reading. |
| `getProjectContext` | ADF bundle resolved for a given task or trigger keywords. |
| `getProjectState` | Constraint validation results across all loaded modules. |
| `getArchitecturalDecisions` | Load-bearing constraints from `core.adf`. |
| `getRecentChanges` | Recent git commits classified by type. |
| `charter_blast` | Blast radius for one or more source files. |
| `charter_surface` | API surface — HTTP routes and D1/SQLite schema tables. |
| `updateEvidence` | **Write-back.** Measures metric source files, patches ADF with current values, returns before/after diff + live constraint status. |

#### `updateEvidence` — keeping ADF metrics accurate

Call after code changes that affect tracked metrics:

```json
{ "tool": "updateEvidence" }
{ "tool": "updateEvidence", "dryRun": true }
{ "tool": "updateEvidence", "metrics": ["total_loc", "test_count"] }
```

Returns measured values, per-file changes, constraint status, and a hint to run `charter adf sync --write` to update `.adf.lock`.

---

## charter context

Pre-digested repo brief for AI agents. Composes routes (surface), hotspots (blast), sensitivity tags, and governance posture into a single bounded markdown document.

```bash
npx charter context                   # print brief + write .charter/context.md
npx charter context --stdout-only     # print only, no file write
npx charter context --verbose         # no token ceiling (for human reading)
npx charter context --write           # write .charter/context.md only (for hooks)
```

| Section | Source |
|---------|--------|
| Identity | `.charter/config.json`, `manifest.adf`, `package.json` |
| Surface | `charter surface` (routes + D1 tables) |
| Hotspots | `charter blast` (top hot files by importer count) |
| Sensitivity | `.charter/config.json` + ADF `SENSITIVITY` sections |
| Governance | `.ai/manifest.adf` module routing |

**Token budget:** capped at 2000 tokens. Sections truncated in this order when over budget: hotspots tail → D1 tables → routes → governance ON_DEMAND entries. Use `--verbose` to remove the ceiling.

**MCP:** `charter serve` registers `charter_brief` — call it first in any agent session.

**Post-commit hook** (keeps brief fresh):
```bash
echo 'charter context --write' >> .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

---

## charter context-refresh

Generates a live session snapshot and writes it to `.ai/context.adf` and `.ai/context.snapshot.json`.

```bash
npx charter context-refresh
npx charter context-refresh --sources git
npx charter context-refresh --sources git,github
npx charter context-refresh --sources repo-intel
npx charter context-refresh --once --ttl-minutes 30
npx charter context-refresh --format json
```

| Flag | Description |
|------|-------------|
| `--sources <csv>` | Sources: `git`, `github`, `repo-intel` |
| `--output <path>` | Mirror a markdown snapshot to a file |
| `--ai-dir <dir>` | Target ADF directory (default: `.ai`) |
| `--once` | Skip refresh when snapshot is newer than TTL |
| `--ttl-minutes <n>` | TTL window used by `--once` (default: `30`) |
| `--force` | Bypass TTL and refresh immediately |

| Source | Description |
|--------|-------------|
| `git` | Local git branch, working tree, and recent commit log |
| `github` | Open issues from the GitHub API (requires `GITHUB_TOKEN`) |
| `repo-intel` | GitHub history via `gh` CLI — issues, PRs, releases, computed summary. Writes `.charter/repo-intel/snapshot.json`. Skips gracefully when `gh` is unavailable. |

---

## Global Flags

| Flag | Effect |
|---|---|
| `--config <path>` | Path to `.charter/` directory (default: `.charter/`) |
| `--format json` | Machine-readable output with stable schemas |
| `--ci` | Non-interactive, deterministic exit codes |
| `--yes` | Accept all prompts (for automation) |
| `--preset <name>` | Stack preset (`worker`, `frontend`, `backend`, `fullstack`, `docs`, `rust-wasm`) |
| `--detect-only` | Setup mode: detect stack/preset and exit |
| `--no-dependency-sync` | Setup mode: do not rewrite `@stackbilt/cli` devDependency |
| `--force` | Overwrite existing files (hooks, ADF modules, config) |

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success / pass |
| `1` | Policy violation (CI mode: governance threshold breached) |
| `2` | Runtime / config / usage error |
