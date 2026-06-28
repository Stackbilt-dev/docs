---
title: "CodeBeast"
description: "Adversarial code review agent and passive repo map generator — severity-classified CI reviews, cross-commit pattern memory, and injectable repo maps for AEGIS/MARA."
section: "platform"
order: 27
color: "#dc2626"
tag: "27"
lastVerified: "2026-06-28"
---

# CodeBeast

**GitHub:** Stackbilt-dev/codebeast (private) · TypeScript

Part of the [Stackbilt ecosystem](/ecosystem). Adversarial code review agent and passive repo map generator. Watches GitHub repos on every push — classifies commit severity, dispatches to Workers AI for review, and generates immutable per-commit repo maps for downstream agent context injection.

Peer to MARA, subordinate to [AEGIS Core](/aegis-core) routing. Findings are formatted for AEGIS ingestion with correlation IDs for cross-agent de-duplication.

---

## What It Does

### Adversarial Code Review

1. A GitHub push webhook fires
2. A deterministic severity classifier (no model) routes the diff: `HIGH` / `MID` / `LOW`
3. HIGH and MID diffs dispatch to Workers AI (`@cf/meta/llama-3.3-70b-instruct-fp8-fast`) for structured review
4. LOW (style-only) changes skip review — map only
5. Findings are persisted in D1 with a `pattern_hash` for cross-commit memory
6. Results are formatted into AEGIS findings payloads with correlation IDs

Reviews are cross-commit — CodeBeast remembers patterns it has seen before and escalates recurring issues.

### Passive Repo Map Generation

Every commit produces an immutable map: exported symbols, inter-module dependencies, function signatures, and module boundaries. Stored in D1 (queryable) and KV (fast retrieval). Designed to be injected as context into cloud-based task executors.

---

## Architecture

```
GitHub Webhook
      │
      ▼
[codebeast-worker] ──► [severity-classifier]
      │                        │
      ▼                        ▼
[webhook-ingestion-queue]   HIGH/MID → Workers AI (review)
      │                     LOW      → map only
      ▼
  ┌───┴───┐
  ▼       ▼
[review-session-do]   [repo-map-generator]
  │       │                 │       │
  ▼       ▼                 ▼       ▼
 D1    AuditLog            D1      KV
  │
  ▼
[aegis-formatter] ──► AEGIS (correlation ID de-duplication)
```

**Runtime:** Cloudflare Workers + Durable Objects  
**Storage:** D1 (9 tables), KV (fast blob reads)  
**Async:** Cloudflare Queues (webhook ingestion buffer)  
**Auth:** [edge-auth](/edge-auth) service binding

---

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/webhook/github` | POST | GitHub push webhook receiver — HMAC-SHA256 validated, dual-secret rotation |
| `/repo-map` | GET | Retrieve repo map for a commit. Params: `repo`, `commit`. KV fast-path, D1 fallback |
| `/rpc` | POST | Stateless MCP JSON-RPC endpoint for service binding consumers (AEGIS, MARA) |
| `/health` | GET | Readiness probe — D1 and DO reachability |

---

## Severity Classification

A deterministic rules engine classifies diffs before any model call:

| Severity | Triggers | Action |
|----------|---------|--------|
| `HIGH` | Auth changes, secret handling, dependency modifications | Workers AI review |
| `MID` | Logic changes, API surface changes | Workers AI review |
| `LOW` | Style-only, whitespace, comments | Map only, no review |

When classifier confidence falls below threshold, the system defaults to `HIGH` (fail-safe).

---

## Review Memory

Each finding produces a `pattern_hash` stored in `ReviewMemory` (D1). When the same pattern appears in a later commit, occurrence counts increment. Memory survives Durable Object evictions via D1 as source of truth. Enables:

- Recurring issue escalation
- Suppression of acknowledged false positives
- Cross-PR pattern correlation

---

## AEGIS Integration

Completed reviews are formatted into AEGIS findings payloads:

- Push events use commit SHA as correlation ID
- PR events use `pr-{number}`
- AEGIS router merges overlapping findings from CodeBeast and MARA with `AUDIT > ACT` priority

AEGIS communicates with CodeBeast via the `/rpc` MCP JSON-RPC endpoint:

| Tool | Description |
|------|-------------|
| `codebeast_review_status` | Get review session status by session ID or commit SHA |
| `codebeast_get_findings` | Retrieve findings with optional severity filter |
| `codebeast_get_repo_map` | Retrieve per-commit repo map entries |
| `codebeast_get_review_memory` | Get recurring patterns tracked across commits |

---

## Trust Page Integration

CodeBeast issues signed `/decide` receipts used by [stackbilt-web](/stackbilt-web)'s Trust Verifier (`trust.stackbilder.com`). The `CODEBEAST` service binding in stackbilt-web calls the `/rpc` endpoint to fetch and verify these receipts for public display.

---

## Setup

```bash
npm install
npx wrangler d1 migrations apply REVIEW_DB --local
npx wrangler dev
```

Required secrets (via `wrangler secret put`):

| Secret | Purpose |
|--------|---------|
| `GITHUB_WEBHOOK_SECRET` | HMAC-SHA256 signing secret for webhook validation |
| `GITHUB_WEBHOOK_SECRET_PREVIOUS` | Previous secret during rotation window |
| `GITHUB_API_TOKEN` | GitHub API token for cloud fix pipeline (branch, commit, PR creation) |
