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

**Exit codes:**
- `0` — all commits pass
- `1` — policy violations found
- `2` — tool error

## charter drift

Scans the codebase for deviations from your blessed stack patterns. Detects unapproved dependencies, frameworks, and patterns defined in `.charter/config.json`.

```bash
npx charter drift                         # scan + print report
npx charter drift --ci --format json      # CI mode
```

## charter audit

Generates a governance posture report: risk score, governed commit ratio, recent violations, and trend data.

```bash
npx charter audit
npx charter audit --format json
```

## charter classify

Determines the change scope for staged changes:

| Scope | Meaning |
|---|---|
| `SURFACE` | UI/copy only, low risk |
| `LOCAL` | Contained to one module |
| `CROSS_CUTTING` | Touches multiple systems, requires ADR |

```bash
npx charter classify                      # classify staged diff
npx charter classify --format json
```

## charter hook

Installs git hooks that normalize governance trailers at commit time.

```bash
npx charter hook install --commit-msg
```

## Global Flags

| Flag | Effect |
|---|---|
| `--format json` | Machine-readable output |
| `--ci` | Non-interactive, deterministic exit codes |
| `--yes` | Accept all prompts (for automation) |
