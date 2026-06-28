---
title: "n8n-transpiler"
description: "Cloudflare Worker that transpiles n8n workflow JSON into deployable Cloudflare Worker projects — webhook triggers, HTTP, conditionals, DB queries, AI nodes."
section: "ecosystem"
order: 23
color: "#6366f1"
tag: "23"
lastVerified: "2026-06-28"
---

# n8n-transpiler

**GitHub:** [Stackbilt-dev/n8n-transpiler](https://github.com/Stackbilt-dev/n8n-transpiler) · Apache-2.0

Part of the [Stackbilt ecosystem](/ecosystem). A Cloudflare Worker that transpiles n8n workflow JSON into deployable Cloudflare Worker projects. Compiler pipeline wrapped in a Hono API with bearer-token auth. Pairs with the [Stackbilder platform](/platform) scaffold engine for full project generation.

---

## API

### `GET /health`

Returns service status. No auth required.

### `POST /transpile`

Accepts an n8n workflow and returns scaffold-ready files.

**Auth:** `Authorization: Bearer <TRANSPILER_TOKEN>`

**Request:**

```json
{
  "workflow": {
    "name": "My Workflow",
    "nodes": [...],
    "connections": {...}
  }
}
```

**Response:**

```json
{
  "files": [
    { "path": "src/index.ts", "content": "..." },
    { "path": "wrangler.toml", "content": "..." },
    { "path": "README.md", "content": "..." },
    { "path": "package.json", "content": "..." },
    { "path": "tsconfig.json", "content": "..." }
  ],
  "summary": {
    "workflowName": "My Workflow",
    "totalNodes": 5,
    "supportedNodes": 4,
    "unsupportedNodes": 1,
    "resources": {
      "secrets": 1,
      "databases": 0,
      "ai": false,
      "queues": 1,
      "cronTriggers": 0
    }
  },
  "meta": { "durationMs": 12, "inputNodes": 5, "outputFiles": 5 }
}
```

---

## Supported Nodes

The compiler pipeline handles:

| Node type | Notes |
|-----------|-------|
| Webhook trigger | `fetch` handler entry point |
| Schedule trigger | Cloudflare cron via `wrangler.toml` |
| HTTP Request | `fetch()` calls with configurable auth |
| IF / Switch | Branching conditionals |
| SplitInBatches | Loop helper |
| Data transform | Object mapper |
| Postgres / MySQL | Hyperdrive D1 proxy |
| AI | Workers AI stub |
| Code | Stub with original code as comment |

Unsupported nodes are reported in `summary.unsupportedNodes` and emitted as stubs.

---

## Architecture

```
POST /transpile
  → WorkflowParser (n8n JSON → IR)
  → WorkerGeneratorV2 (IR → TypeScript + config files)
  → files[] response
```

---

## Setup

```bash
npm install
wrangler secret put TRANSPILER_TOKEN
wrangler dev
```

```bash
wrangler deploy
```

---

## Example

Convert an n8n webhook-triggered workflow that calls a Postgres DB and posts a Slack message:

```bash
curl -X POST https://n8n-transpiler.<subdomain>.workers.dev/transpile \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -d @my-workflow.json
```

The response includes `src/index.ts` (typed Hono Worker), `wrangler.toml` (with Hyperdrive binding for the DB), and a `README.md` listing any unsupported nodes and manual steps.
