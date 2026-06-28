---
title: "stackbilt-build"
description: "Commercial Stackbilt CLI — stackbilt run, stackbilt architect, stackbilt login, and stackbilt scaffold commands for generating deployment-ready Cloudflare Workers projects."
section: "ecosystem"
order: 25
color: "#64748b"
tag: "25"
lastVerified: "2026-06-28"
---

# stackbilt-build

**GitHub:** [Stackbilt-dev/stackbilt-build](https://github.com/Stackbilt-dev/stackbilt-build) · Proprietary

**npm:** `@stackbilt/build`

Part of the [Stackbilt ecosystem](/ecosystem). The commercial surface of the Stackbilt toolchain — generates deployment-ready Cloudflare Workers projects from a plain-language description, manages API key credentials, and writes scaffold files to disk.

For the OSS governance tools (`audit`, `drift`, `validate`, `classify`, `adf`), see [Charter CLI](/getting-started).

---

## Commands

| Command | Description |
|---------|-------------|
| `stackbilt run` | Generate a deployment-ready Cloudflare Workers project from a plain-language description |
| `stackbilt architect` | Run the 6-mode architecture pipeline (PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT) |
| `stackbilt scaffold` | Write scaffold files to disk from a completed architecture run |
| `stackbilt login` | Authenticate with `stackbilder.com` and store API credentials |

---

## Relationship to Charter

`@stackbilt/build` is the commercial CLI surface. `@stackbilt/cli` ([Charter](/getting-started)) is the OSS governance layer. They operate independently but are designed to be used together:

```
stackbilt architect    →  generates governed blueprint
Charter CLI            →  validates drift + ADF compliance in CI
stackbilt scaffold     →  writes deployable project from blueprint
Charter CLI            →  enforces commit trailers + stack compliance at merge
```

---

## Platform Access

All `stackbilt-build` commands require an active [Stackbilder platform](/platform) account. The generated projects follow the same blessed-pattern ledger (Cloudflare Workers, D1, KV, Queues) enforced by the platform's governance engine.

For full pipeline documentation, API access, and Pro/Team tier features, see the [Stackbilder Platform](/platform) and [API Reference](/api-reference).
