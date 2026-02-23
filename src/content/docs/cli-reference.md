---
title: "CLI Reference"
section: "charter"
order: 2
color: "#f59e0b"
tag: "02"
---

# CLI Reference

Use `npx charter ...` if Charter is installed as a local dev dependency. Use `charter ...` if installed globally.

## charter validate

Checks commit trailers for governance compliance. Every commit should carry a `Governed-By:` trailer linking it to an ADR or governance decision.

```bash
npx charter validate                       # check recent commits
npx charter validate --ci                  # CI mode — exits 1 on violations
npx charter validate --ci --format json    # machine-readable output
```

Supports `--range <revset>` to validate a specific commit range.

**Exit codes:**
- `0` — all commits pass
- `1` — policy violations found
- `2` — tool error

## charter drift

Scans the codebase for deviations from your blessed stack patterns. Detects unapproved dependencies, frameworks, and patterns defined in `.charter/config.json`.

```bash
npx charter drift                         # scan + print report
npx charter drift --ci --format json      # CI mode
npx charter drift --path ./packages       # scan a specific directory
```

## charter audit

Generates a governance posture report: risk score, governed commit ratio, recent violations, and trend data.

```bash
npx charter audit
npx charter audit --format json
```

Supports `--range <revset>` to audit a specific commit range.

## charter classify

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

## charter hook

Installs git hooks that normalize governance trailers at commit time.

```bash
npx charter hook install --commit-msg
```

## charter setup

Bootstraps `.charter/` config and optionally writes CI workflow scaffolding.

```bash
npx charter setup --detect-only --format json
npx charter setup --ci github --yes
npx charter setup --preset fullstack --ci github --yes
```

Setup-specific options:

- `--ci github`
- `--preset <worker|frontend|backend|fullstack>`
- `--detect-only`
- `--no-dependency-sync`

## charter init

Scaffolds the `.charter/` config directory without running the full setup workflow.

```bash
npx charter init
npx charter init --preset worker
```

## charter doctor

Checks CLI installation and repository config health.

```bash
npx charter doctor
npx charter doctor --format json
```

## charter why

Prints a quick explanation of Charter's governance value and adoption ROI.

```bash
npx charter why
```

## Global Flags

| Flag | Effect |
|---|---|
| `--config <path>` | Path to `.charter/` directory (default: `.charter/`) |
| `--format json` | Machine-readable output |
| `--ci` | Non-interactive, deterministic exit codes |
| `--yes` | Accept all prompts (for automation) |
| `--preset <name>` | Stack preset (`worker`, `frontend`, `backend`, `fullstack`) |
| `--detect-only` | Setup mode: detect stack/preset and exit |
| `--no-dependency-sync` | Setup mode: do not rewrite `@stackbilt/cli` devDependency |
