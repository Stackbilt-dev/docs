---
title: "Getting Started"
section: "charter"
order: 1
color: "#2ea043"
tag: "01"
---

# Getting Started

Charter is a local-first governance CLI for software repos. It validates commit governance, detects stack drift, and scores risk — locally and in CI, with no SaaS dependency.

## Install

Recommended: local dev dependency per repo.

```bash
npm install --save-dev @stackbilt/cli
```

pnpm workspace root:

```bash
pnpm add -Dw @stackbilt/cli
```

Global (optional, puts `charter` on your PATH):

```bash
npm install -g @stackbilt/cli
```

## Bootstrap a Repo

```bash
# Preview what charter detects — no files written
npx charter setup --detect-only --format json

# Write governance baseline + optional CI workflow
npx charter setup --ci github --yes

# Mixed repos (frontend + backend): choose preset explicitly
npx charter setup --detect-only
npx charter setup --preset fullstack --ci github --yes
```

`setup` writes:
- `.charter/config.json` — governance baseline config
- `governance.md` — human-readable policy summary
- `.github/workflows/governance.yml` — CI workflow (if `--ci github`)

## Verify the Setup

```bash
npx charter doctor --format json
npx charter
```

`charter` with no arguments prints a live governance snapshot: risk score, governed commit ratio, drift status.
